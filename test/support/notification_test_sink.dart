import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// A [NotificationService] sink that writes notification payloads straight to
/// the fake Firestore, standing in for the encrypted Cloud Function
/// (`EncryptionService.saveNotification`) that runs server-side in production.
///
/// Lets unit tests assert the built payload (title/body/metadata) without a
/// live Cloud Functions backend.
Future<void> Function(List<String>, Map<String, dynamic>) fakeNotifSink(
  FakeFirebaseFirestore db,
) {
  return (userIds, data) async {
    for (final uid in userIds) {
      await db.collection('users').doc(uid).collection('notifications').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  };
}
