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
      int? currentPosition,
    }) async {
      final doc = <String, dynamic>{
        'patientId': patientId,
        'queueType': queueType,
        'status': status,
        'priorityNumber': priorityNumber,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAtMs),
      };
      if (currentPosition != null) doc['currentPosition'] = currentPosition;
      final ref = await db.collection('queue').add(doc);
      return ref.id;
    }

    test('writes currentPosition by priority then arrival order', () async {
      // Seeded out of final order on purpose.
      final low = await seed(
          patientId: 'p-low', priorityNumber: 3, createdAtMs: 1000);
      final emergency = await seed(
          patientId: 'p-emerg', priorityNumber: 1, createdAtMs: 3000);
      final moderateEarly = await seed(
          patientId: 'p-mod-early', priorityNumber: 2, createdAtMs: 1000);
      final moderateLate = await seed(
          patientId: 'p-mod-late', priorityNumber: 2, createdAtMs: 2000);

      await QueuePositionFanout.run(notif, firestore: db);

      Future<int> pos(String id) async =>
          ((await db.collection('queue').doc(id).get()).data()!['currentPosition']
              as num)
              .toInt();

      expect(await pos(emergency), 1);
      expect(await pos(moderateEarly), 2);
      expect(await pos(moderateLate), 3);
      expect(await pos(low), 4);
    });

    test('ignores docs that are not waiting_nurse in the nurse lane', () async {
      final waiting = await seed(
          patientId: 'p1', priorityNumber: 1, createdAtMs: 1000);
      final doctor = await seed(
          patientId: 'p2',
          priorityNumber: 1,
          createdAtMs: 1000,
          status: 'waiting_doctor',
          queueType: 'doctor');
      final preArrival = await seed(
          patientId: 'p3',
          priorityNumber: 1,
          createdAtMs: 1000,
          status: 'pre_arrival');

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
  });
}
