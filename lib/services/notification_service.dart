import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes patient-facing notifications into the patient's own
/// `users/{patientId}/notifications` subcollection — which is exactly what the
/// patient Notifications screen reads. Keeping this in one place means every
/// notification reaches the patient and uses friendly, jargon-free wording.
class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Notify a patient that a nurse changed their triage level after assessing
  /// vitals. [oldLevel] and [newLevel] must already be patient-friendly words
  /// (e.g. "Emergency", "Urgent", "Non-Urgent") — never internal codes.
  Future<void> notifyTriageOverride({
    required String patientId,
    required String oldLevel,
    required String newLevel,
    required String nurseName,
    required String reason,
  }) async {
    await _firestore
        .collection('users')
        .doc(patientId)
        .collection('notifications')
        .add({
      'type': 'triage_update',
      'title': 'Your priority was updated',
      'message': 'Your priority changed from $oldLevel to $newLevel after '
          '$nurseName reviewed your details. $reason.',
      'oldLevel': oldLevel,
      'newLevel': newLevel,
      'nurseName': nurseName,
      'reason': reason,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
