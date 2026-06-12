import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/notification_service.dart';
import 'wait_estimator.dart';

/// Staff-side fan-out of live queue positions.
///
/// Firestore security rules stop a patient from reading any queue document but
/// their own, so patients cannot compute "I am #N in line" from the collection.
/// Instead, every time the lane changes (a patient checks in, or a nurse
/// finalises) staff — who *can* read the whole `queue` — recompute each waiting
/// patient's rank and write `currentPosition` back onto that patient's own doc.
/// The patient then just listens to their single document.
///
/// This is **best-effort**: it must never block, slow, or crash the operation
/// that triggered it. Every failure mode is swallowed.
class QueuePositionFanout {
  QueuePositionFanout._();

  /// Recompute and write `currentPosition` for every patient currently
  /// `waiting_nurse`, and notify anyone whose position actually changed.
  ///
  /// [firestore] is injectable purely for tests; production callers pass only
  /// the [notifService] and the live instance is used.
  static Future<void> run(
    NotificationService notifService, {
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // Ordering mirrors the nurse lane: priority first, then arrival order.
      // Backed by the composite index queueType+status+priorityNumber+createdAt.
      final snap = await db
          .collection('queue')
          .where('queueType', isEqualTo: 'nurse')
          .where('status', isEqualTo: 'waiting_nurse')
          .orderBy('priorityNumber')
          .orderBy('createdAt')
          .get();

      if (snap.docs.isEmpty) return;

      final batch = db.batch();

      // Patients whose position actually moved (including their first-ever
      // assignment, old == null). Collected here and notified AFTER the batch
      // is built so a slow notify can't delay the writes.
      final moved = <_MovedPatient>[];

      for (var i = 0; i < snap.docs.length; i++) {
        final doc = snap.docs[i];
        final data = doc.data();
        final newPosition = i + 1;
        final oldPosition = (data['currentPosition'] as num?)?.toInt();

        // Only ever touch currentPosition — never the ordering fields, or a
        // racing fan-out could corrupt the lane.
        batch.update(doc.reference, {'currentPosition': newPosition});

        if (oldPosition != newPosition) {
          final patientId = (data['patientId'] as String?)?.trim();
          if (patientId != null && patientId.isNotEmpty) {
            final level = (data['triageLevel'] as String?) ?? 'LOW';
            moved.add(_MovedPatient(patientId, newPosition, level));
          }
        }
      }

      await batch.commit();

      // Notifications are fire-and-forget and individually ignored: a single
      // patient's blocked notify must not stop the others, and none of them
      // can surface an error to the staff action that triggered the fan-out.
      for (final p in moved) {
        notifService
            .notifyQueueUpdate(
              patientId: p.patientId,
              position: p.position,
              estimatedWaitMinutes: 0,
              bodyOverride: _bodyEn(p.position, p.triageLevel),
              bodyArOverride: _bodyAr(p.position, p.triageLevel),
            )
            .ignore();
      }
    } catch (_) {
      // Fan-out is best-effort — never blocks or crashes the triggering
      // operation. Positions self-heal on the next arrival/finalize event.
    }
  }

  // position 1 has no meaningful wait range — it's a "be ready" prompt.
  static String _bodyEn(int position, String triageLevel) => position <= 1
      ? 'Your queue position: #1 — Please be ready to be seen'
      : 'Your queue position: #$position — Estimated wait: '
            '${WaitEstimator.waitText(triageLevel, position - 1)}';

  static String _bodyAr(int position, String triageLevel) => position <= 1
      ? 'موقعك في الطابور: #1 — يرجى الاستعداد'
      : 'موقعك في الطابور: #$position — الوقت المتوقع: '
            '${WaitEstimator.waitText(triageLevel, position - 1)}';
}

class _MovedPatient {
  final String patientId;
  final int position;
  final String triageLevel;
  const _MovedPatient(this.patientId, this.position, this.triageLevel);
}
