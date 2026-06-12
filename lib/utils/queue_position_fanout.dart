import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';
import 'lane_order.dart';
import 'wait_estimator.dart';

/// Staff-side fan-out of live queue positions and wait estimates.
///
/// Firestore security rules stop a patient from reading any queue document but
/// their own, so patients cannot compute "I am #N in line" from the collection.
/// Instead, staff sessions — which *can* read the whole `queue` — recompute
/// each waiting patient's rank and expected wait, and write `currentPosition`
/// and `estimatedWaitMinutes` back onto that patient's own doc. The patient
/// then just listens to their single document.
///
/// Ordering is [LaneOrder.compare] — the same comparator the dashboards use —
/// so the "#N" a patient sees always matches the "#N" a nurse sees.
///
/// This is **best-effort**: it must never block, slow, or crash the operation
/// that triggered it. Every failure mode is swallowed.
class QueuePositionFanout {
  QueuePositionFanout._();

  static bool _autoRunning = false;

  /// Snapshot-driven trigger for staff queue streams (nurse + staff
  /// dashboards). Call it with every snapshot's docs: it recomputes only when
  /// some doc's stored position or wait has drifted from the canonical lane,
  /// so the snapshot fired by the fan-out's own writes finds nothing stale
  /// and the write → snapshot → write cycle terminates.
  ///
  /// This is how a *patient* checking in gets a position at all: the patient
  /// cannot run the fan-out (rules deny the lane-wide read), but their new doc
  /// appears in every staff stream, which calls this, which fans out.
  static void autoSync(
    List<QueryDocumentSnapshot> docs,
    NotificationService notifService,
  ) {
    if (_autoRunning) return;

    final lane =
        docs
            .map(
              (d) =>
                  (d.data() as Map<String, dynamic>?) ??
                  const <String, dynamic>{},
            )
            .toList()
          ..sort(LaneOrder.compare);
    final waits = LaneOrder.expectedWaits(lane);

    var stale = false;
    for (var i = 0; i < lane.length; i++) {
      final pos = (lane[i]['currentPosition'] as num?)?.toInt();
      final wait = (lane[i]['estimatedWaitMinutes'] as num?)?.toInt();
      if (pos != i + 1 || wait != waits[i]) {
        stale = true;
        break;
      }
    }
    if (!stale) return;

    _autoRunning = true;
    run(notifService).whenComplete(() => _autoRunning = false);
  }

  /// Recompute and write `currentPosition` / `estimatedWaitMinutes` for every
  /// patient currently `waiting_nurse`, and notify anyone whose position
  /// actually changed — in either direction.
  ///
  /// [firestore] is injectable purely for tests; production callers pass only
  /// the [notifService] and the live instance is used.
  static Future<void> run(
    NotificationService notifService, {
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // No server-side orderBy: Firestore silently drops docs missing an
      // ordered-by field, and the canonical comparator needs all of them.
      final raw = await db
          .collection('queue')
          .where('queueType', isEqualTo: 'nurse')
          .where('status', isEqualTo: 'waiting_nurse')
          .get();

      if (raw.docs.isEmpty) return;

      final docs = raw.docs.toList()
        ..sort((a, b) => LaneOrder.compare(a.data(), b.data()));
      final waits = LaneOrder.expectedWaits(docs.map((d) => d.data()).toList());

      final batch = db.batch();

      // Patients whose position actually moved (including their first-ever
      // assignment, old == null). Collected here and notified AFTER the batch
      // is built so a slow notify can't delay the writes.
      final moved = <_MovedPatient>[];
      var writes = 0;

      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data();
        final newPosition = i + 1;
        final newWait = waits[i];
        final oldPosition = (data['currentPosition'] as num?)?.toInt();
        final oldWait = (data['estimatedWaitMinutes'] as num?)?.toInt();

        // Skip fully-unchanged docs. This makes the fan-out convergent: the
        // snapshot fired by its own writes triggers autoSync again, which
        // finds nothing stale and stops the cycle.
        if (oldPosition == newPosition && oldWait == newWait) continue;

        // Only ever touch the fanned-out fields — never the ordering fields,
        // or a racing fan-out could corrupt the lane.
        batch.update(doc.reference, {
          'currentPosition': newPosition,
          'estimatedWaitMinutes': newWait,
        });
        writes++;

        // Notify on position changes only — a wait-minutes drift alone (a
        // patient ahead got re-leveled) updates the card silently.
        if (oldPosition != newPosition) {
          final patientId = (data['patientId'] as String?)?.trim();
          if (patientId != null && patientId.isNotEmpty) {
            moved.add(
              _MovedPatient(patientId, oldPosition, newPosition, newWait),
            );
          }
        }
      }

      if (writes == 0) return;
      await batch.commit();
      debugPrint(
        'QueuePositionFanout: wrote positions/waits to $writes doc(s)',
      );

      // Notifications are fire-and-forget and individually ignored: a single
      // patient's blocked notify must not stop the others, and none of them
      // can surface an error to the staff action that triggered the fan-out.
      for (final p in moved) {
        notifService
            .notifyQueueUpdate(
              patientId: p.patientId,
              position: p.newPosition,
              estimatedWaitMinutes: p.waitMinutes,
              bodyOverride: _bodyEn(p),
              bodyArOverride: _bodyAr(p),
            )
            .ignore();
      }
    } catch (e) {
      // Fan-out is best-effort — never blocks or crashes the triggering
      // operation. Positions self-heal on the next staff stream snapshot.
      // Loud in debug builds so a rules/index failure is never invisible.
      debugPrint('QueuePositionFanout: fan-out failed — $e');
    }
  }

  static String _waitRange(int waitMinutes) =>
      '${WaitEstimator.rangeLow(waitMinutes)}–${WaitEstimator.rangeHigh(waitMinutes)} min';

  // #1 is being assessed by the nurse now; #2 is literally next (be ready);
  // #3+ gets a wait-time estimate. Direction matters: being pushed back by a
  // more urgent arrival must say so honestly, not claim the patient "moved up".
  static String _bodyEn(_MovedPatient p) {
    if (p.newPosition <= 1) return "It's your turn — you're being seen now";
    if (p.newPosition == 2) {
      return "You're next — please be ready. Est. wait: ${_waitRange(p.waitMinutes)}";
    }
    if (p.oldPosition != null && p.newPosition > p.oldPosition!) {
      return 'A more urgent patient was prioritized — you are now '
          '#${p.newPosition}. Est. wait: ${_waitRange(p.waitMinutes)}';
    }
    if (p.oldPosition == null) {
      return "You're #${p.newPosition} in the queue — Est. wait: "
          '${_waitRange(p.waitMinutes)}';
    }
    return 'You moved up to #${p.newPosition} — Est. wait: '
        '${_waitRange(p.waitMinutes)}';
  }

  static String _bodyAr(_MovedPatient p) {
    if (p.newPosition <= 1) return 'حان دورك — تتم رؤيتك الآن';
    if (p.newPosition == 2) {
      return 'أنت التالي — يرجى الاستعداد. الوقت المتوقع: ${_waitRange(p.waitMinutes)}';
    }
    if (p.oldPosition != null && p.newPosition > p.oldPosition!) {
      return 'تمت أولوية حالة أكثر إلحاحاً — موقعك الآن #${p.newPosition}. '
          'الوقت المتوقع: ${_waitRange(p.waitMinutes)}';
    }
    if (p.oldPosition == null) {
      return 'موقعك في الطابور #${p.newPosition} — الوقت المتوقع: '
          '${_waitRange(p.waitMinutes)}';
    }
    return 'تقدّمت إلى #${p.newPosition} — الوقت المتوقع: '
        '${_waitRange(p.waitMinutes)}';
  }
}

class _MovedPatient {
  final String patientId;
  final int? oldPosition;
  final int newPosition;
  final int waitMinutes;
  const _MovedPatient(
    this.patientId,
    this.oldPosition,
    this.newPosition,
    this.waitMinutes,
  );
}
