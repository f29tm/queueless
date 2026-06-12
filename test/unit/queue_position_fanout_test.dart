import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/services/notification_service.dart';
import 'package:queueless/utils/queue_position_fanout.dart';

void main() {
  group('QueuePositionFanout — public interface (tracer bullet)', () {
    test('run is a static async method that accepts a NotificationService', () {
      // Compile-time tracer: this only type-checks if QueuePositionFanout.run
      // exists with the agreed shape — a static method whose first positional
      // argument is a NotificationService and which returns a Future<void>.
      // No Firebase is touched here; we never invoke run().
      final Future<void> Function(NotificationService) fn =
          QueuePositionFanout.run;
      expect(fn, isNotNull);
    });
  });

  group('QueuePositionFanout.run — behaviour', () {
    late FakeFirebaseFirestore db;
    late NotificationService notif;

    setUp(() {
      db = FakeFirebaseFirestore();
      notif = NotificationService(firestore: db);
    });

    Future<String> seed({
      required String patientId,
      required int priorityNumber,
      required int createdAtMs,
      String status = 'waiting_nurse',
      String queueType = 'nurse',
      String? triageLevel,
      int? currentPosition,
      int? estimatedWaitMinutes,
    }) async {
      final doc = <String, dynamic>{
        'patientId': patientId,
        'queueType': queueType,
        'status': status,
        'priorityNumber': priorityNumber,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAtMs),
      };
      if (triageLevel != null) doc['triageLevel'] = triageLevel;
      if (currentPosition != null) doc['currentPosition'] = currentPosition;
      if (estimatedWaitMinutes != null) {
        doc['estimatedWaitMinutes'] = estimatedWaitMinutes;
      }
      final ref = await db.collection('queue').add(doc);
      return ref.id;
    }

    test('writes currentPosition by priority then arrival order', () async {
      // Seeded out of final order on purpose.
      final low = await seed(
        patientId: 'p-low',
        priorityNumber: 3,
        createdAtMs: 1000,
      );
      final emergency = await seed(
        patientId: 'p-emerg',
        priorityNumber: 1,
        createdAtMs: 3000,
      );
      final moderateEarly = await seed(
        patientId: 'p-mod-early',
        priorityNumber: 2,
        createdAtMs: 1000,
      );
      final moderateLate = await seed(
        patientId: 'p-mod-late',
        priorityNumber: 2,
        createdAtMs: 2000,
      );

      await QueuePositionFanout.run(notif, firestore: db);

      Future<int> pos(String id) async =>
          ((await db.collection('queue').doc(id).get())
                      .data()!['currentPosition']
                  as num)
              .toInt();

      expect(await pos(emergency), 1);
      expect(await pos(moderateEarly), 2);
      expect(await pos(moderateLate), 3);
      expect(await pos(low), 4);
    });

    test('ignores docs that are not waiting_nurse in the nurse lane', () async {
      final waiting = await seed(
        patientId: 'p1',
        priorityNumber: 1,
        createdAtMs: 1000,
      );
      final doctor = await seed(
        patientId: 'p2',
        priorityNumber: 1,
        createdAtMs: 1000,
        status: 'waiting_doctor',
        queueType: 'doctor',
      );
      final preArrival = await seed(
        patientId: 'p3',
        priorityNumber: 1,
        createdAtMs: 1000,
        status: 'pre_arrival',
      );

      await QueuePositionFanout.run(notif, firestore: db);

      Future<Object?> field(String id) async =>
          (await db.collection('queue').doc(id).get())
              .data()!['currentPosition'];

      expect(await field(waiting), 1);
      expect(await field(doctor), isNull);
      expect(await field(preArrival), isNull);
    });

    test('empty lane is a no-op and does not throw', () async {
      await expectLater(
        QueuePositionFanout.run(notif, firestore: db),
        completes,
      );
    });

    test(
      'converges — positions already correct means no notifications',
      () async {
        // The staff dashboards re-run the fan-out on every queue snapshot,
        // including the snapshot fired by the fan-out's own writes. A run that
        // finds every currentPosition already correct must write nothing and
        // notify nobody, or the cycle would never terminate (and patients would
        // be spammed with duplicate position alerts).
        await seed(
          patientId: 'p1',
          priorityNumber: 1,
          triageLevel: 'EMERGENCY',
          createdAtMs: 1000,
          currentPosition: 1,
          estimatedWaitMinutes: 0,
        );
        await seed(
          patientId: 'p2',
          priorityNumber: 2,
          triageLevel: 'MODERATE',
          createdAtMs: 2000,
          currentPosition: 2,
          estimatedWaitMinutes: 12,
        );

        await QueuePositionFanout.run(notif, firestore: db);

        for (final uid in ['p1', 'p2']) {
          final notifs = await db
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .get();
          expect(
            notifs.docs,
            isEmpty,
            reason: 'unchanged position must not re-notify $uid',
          );
        }
      },
    );

    test(
      'manual check-ins (PENDING) rank after every AI-triaged patient',
      () async {
        // Manual check-ins store priorityNumber 3 — same as Non-Urgent — but
        // nobody has assessed them, so the lane rule is Emergency → Urgent →
        // Non-Urgent → Manual. A later-arriving Non-Urgent AI patient must
        // still be seen before an earlier manual walk-in.
        final manual = await seed(
          patientId: 'p-manual',
          priorityNumber: 3,
          triageLevel: 'PENDING',
          createdAtMs: 1000,
        );
        final low = await seed(
          patientId: 'p-low',
          priorityNumber: 3,
          triageLevel: 'LOW',
          createdAtMs: 2000,
        );

        await QueuePositionFanout.run(notif, firestore: db);

        Future<int> pos(String id) async =>
            ((await db.collection('queue').doc(id).get())
                        .data()!['currentPosition']
                    as num)
                .toInt();

        expect(await pos(low), 1);
        expect(await pos(manual), 2);
      },
    );

    test(
      'fans out cumulative estimatedWaitMinutes from the acuities ahead',
      () async {
        // The wait written to each doc prices every patient ahead at THEIR
        // service time (Emergency 12, Urgent 20, Non-Urgent 25) — not at the
        // waiting patient's own level.
        final e = await seed(
          patientId: 'p-e',
          priorityNumber: 1,
          triageLevel: 'EMERGENCY',
          createdAtMs: 1000,
        );
        final m = await seed(
          patientId: 'p-m',
          priorityNumber: 2,
          triageLevel: 'MODERATE',
          createdAtMs: 2000,
        );
        final l = await seed(
          patientId: 'p-l',
          priorityNumber: 3,
          triageLevel: 'LOW',
          createdAtMs: 3000,
        );

        await QueuePositionFanout.run(notif, firestore: db);

        Future<int> wait(String id) async =>
            ((await db.collection('queue').doc(id).get())
                        .data()!['estimatedWaitMinutes']
                    as num)
                .toInt();

        expect(await wait(e), 0); // being seen now
        expect(await wait(m), 12); // waits for the Emergency ahead
        expect(await wait(l), 32); // 12 + 20 for the two ahead
      },
    );

    test(
      'pushed-back patient is told a more urgent case was prioritized',
      () async {
        // Two Non-Urgent patients hold #1 and #2; an Emergency walks in and
        // takes #1. The patient pushed from #2 to #3 must get an honest
        // "you moved back" message — never a "you moved up" one.
        await seed(
          patientId: 'p-first',
          priorityNumber: 3,
          triageLevel: 'LOW',
          createdAtMs: 1000,
          currentPosition: 1,
          estimatedWaitMinutes: 0,
        );
        await seed(
          patientId: 'p-second',
          priorityNumber: 3,
          triageLevel: 'LOW',
          createdAtMs: 2000,
          currentPosition: 2,
          estimatedWaitMinutes: 25,
        );
        await seed(
          patientId: 'p-emerg',
          priorityNumber: 1,
          triageLevel: 'EMERGENCY',
          createdAtMs: 3000,
        );

        await QueuePositionFanout.run(notif, firestore: db);
        // Notifications are deliberately fire-and-forget inside run(); give
        // their unawaited write chains a beat to land before asserting.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final notifs = await db
            .collection('users')
            .doc('p-second')
            .collection('notifications')
            .get();
        expect(notifs.docs, hasLength(1));
        final body = notifs.docs.first.data()['body'] as String;
        expect(body, contains('more urgent patient was prioritized'));
        expect(body, contains('#3'));
        expect(body, isNot(contains('moved up')));
      },
    );

    test('first assignment (null → N) writes position and notifies', () async {
      // A fresh check-in has no currentPosition at all — the fan-out must
      // treat that as a move so the patient's hub card leaves "Calculating…".
      final id = await seed(
        patientId: 'p-new',
        priorityNumber: 3,
        createdAtMs: 1000,
      );

      await QueuePositionFanout.run(notif, firestore: db);

      final doc = await db.collection('queue').doc(id).get();
      expect((doc.data()!['currentPosition'] as num).toInt(), 1);

      final notifs = await db
          .collection('users')
          .doc('p-new')
          .collection('notifications')
          .get();
      expect(notifs.docs, hasLength(1));
    });
  });
}
