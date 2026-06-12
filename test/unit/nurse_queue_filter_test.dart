import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/nurse_queue_filter.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<QueryDocumentSnapshot<Object?>> seed(
    String id, {
    required String triageLevel,
    required int priorityNumber,
    required int arrivedAtMs,
    bool noAITriage = false,
  }) async {
    await db.collection('queue').doc(id).set({
      'triageLevel': triageLevel,
      'priorityNumber': priorityNumber,
      'arrivedAt': Timestamp.fromMillisecondsSinceEpoch(arrivedAtMs),
      'noAITriage': noAITriage,
    });
    final snap = await db.collection('queue').doc(id).get();
    // Re-read through a query so we get QueryDocumentSnapshots.
    final q = await db.collection('queue').get();
    return q.docs.firstWhere((d) => d.id == snap.id);
  }

  group('NurseQueueFilter.filterByLevel', () {
    test('returns only docs matching the requested level', () async {
      await seed('a', triageLevel: 'EMERGENCY', priorityNumber: 1, arrivedAtMs: 1000);
      await seed('b', triageLevel: 'MODERATE', priorityNumber: 2, arrivedAtMs: 2000);
      await seed('c', triageLevel: 'EMERGENCY', priorityNumber: 1, arrivedAtMs: 3000);

      final all = (await db.collection('queue').get()).docs;
      final result = NurseQueueFilter.filterByLevel(all, 'EMERGENCY');

      expect(result.map((d) => d.id).toSet(), {'a', 'c'});
    });

    test('null level returns every doc unchanged', () async {
      await seed('a', triageLevel: 'EMERGENCY', priorityNumber: 1, arrivedAtMs: 1000);
      await seed('b', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 2000);

      final all = (await db.collection('queue').get()).docs;
      expect(NurseQueueFilter.filterByLevel(all, null).length, 2);
    });

    test('MANUAL keeps only manual check-ins', () async {
      await seed('a', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 1000, noAITriage: true);
      await seed('b', triageLevel: 'EMERGENCY', priorityNumber: 1, arrivedAtMs: 2000);

      final all = (await db.collection('queue').get()).docs;
      final result = NurseQueueFilter.filterByLevel(all, 'MANUAL');
      expect(result.map((d) => d.id).toList(), ['a']);
    });
  });

  group('NurseQueueFilter.sortByArrival', () {
    test('orders by arrivedAt ascending (earliest first)', () async {
      await seed('late', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 3000);
      await seed('early', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 1000);
      await seed('mid', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 2000);

      final all = (await db.collection('queue').get()).docs;
      final sorted = NurseQueueFilter.sortByArrival(all);
      expect(sorted.map((d) => d.id).toList(), ['early', 'mid', 'late']);
    });
  });

  group('NurseQueueFilter.sortByPriority', () {
    test('orders by priorityNumber ascending (most urgent first)', () async {
      await seed('low', triageLevel: 'LOW', priorityNumber: 3, arrivedAtMs: 1000);
      await seed('emerg', triageLevel: 'EMERGENCY', priorityNumber: 1, arrivedAtMs: 2000);
      await seed('mod', triageLevel: 'MODERATE', priorityNumber: 2, arrivedAtMs: 3000);

      final all = (await db.collection('queue').get()).docs;
      final sorted = NurseQueueFilter.sortByPriority(all);
      expect(sorted.map((d) => d.id).toList(), ['emerg', 'mod', 'low']);
    });
  });

  group('NurseQueueFilter.sortByWaitTime', () {
    test('returns higher estimatedWaitMinutes first', () async {
      await db.collection('queue').doc('short').set({'estimatedWaitMinutes': 5});
      await db.collection('queue').doc('long').set({'estimatedWaitMinutes': 40});
      await db.collection('queue').doc('mid').set({'estimatedWaitMinutes': 20});
      await db.collection('queue').doc('none').set({'patientName': 'x'});

      final all = (await db.collection('queue').get()).docs;
      final sorted = NurseQueueFilter.sortByWaitTime(all);
      // Longest wait first; the doc with no value is treated as 0 and sorts last.
      expect(sorted.map((d) => d.id).toList(), ['long', 'mid', 'short', 'none']);
    });
  });
}
