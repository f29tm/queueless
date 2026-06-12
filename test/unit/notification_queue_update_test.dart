import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/services/notification_service.dart';

import '../support/notification_test_sink.dart';

void main() {
  late FakeFirebaseFirestore db;
  late NotificationService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = NotificationService(firestore: db, notifSink: fakeNotifSink(db));
  });

  Future<Map<String, dynamic>> notifyAndRead(int position) async {
    await svc.notifyQueueUpdate(
      patientId: 'p',
      position: position,
      estimatedWaitMinutes: 30,
    );
    final snap = await db
        .collection('users')
        .doc('p')
        .collection('notifications')
        .get();
    return snap.docs.single.data();
  }

  group('notifyQueueUpdate — "you\'re next" fires at position 2', () {
    test('position 1 means the patient is being seen now', () async {
      final n = await notifyAndRead(1);
      expect(n['title'], "It's Your Turn");
      expect(n['body'], "It's your turn — you're being seen now.");
    });

    test('position 2 is the "You\'re Next" alert', () async {
      final n = await notifyAndRead(2);
      expect(n['title'], "You're Next");
      expect(n['body'], "You're next — please be ready.");
    });

    test('position 3 is a generic queue update with an estimate', () async {
      final n = await notifyAndRead(3);
      expect(n['title'], 'Queue Update');
      expect(n['body'], contains('#3'));
    });
  });
}
