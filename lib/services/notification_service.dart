
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  appointmentCancelled,
  consultationCancelled,
  triageOverride,
  queueUpdate,
  reminder,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'reminder'),
        orElse: () => NotificationType.reminder,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Shared collection reference for any user ─────────────────────────────
  CollectionReference _notifRef(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('notifications');

  // ─── Stream: all notifications (newest first) ─────────────────────────────
  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _notifRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppNotification.fromFirestore(d)).toList());
  }

  // ─── Stream: unread count only (for badge) ────────────────────────────────
  Stream<int> unreadCountStream(String userId) {
    return _notifRef(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PATIENT-FACING NOTIFICATIONS  (doctor → patient)
  // ══════════════════════════════════════════════════════════════════════════

  // ─── Doctor cancels appointment → notify patient ──────────────────────────
  Future<void> notifyAppointmentCancelled({
    required String patientId,
    required String appointmentId,
    required String doctorName,
    required String appointmentDate,
    required String reason,
  }) async {
    await _notifRef(patientId).add({
      'type': NotificationType.appointmentCancelled.name,
      'title': 'Appointment Cancelled',
      'body': '$doctorName has cancelled your appointment on $appointmentDate.',
      'metadata': {
        'appointmentId': appointmentId,
        'doctorName': doctorName,
        'appointmentDate': appointmentDate,
        'reason': reason,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Doctor cancels consultation → notify patient ─────────────────────────
  Future<void> notifyConsultationCancelled({
    required String patientId,
    required String consultationId,
    required String doctorName,
    required String scheduledTime,
    required String reason,
  }) async {
    await _notifRef(patientId).add({
      'type': NotificationType.consultationCancelled.name,
      'title': 'Consultation Cancelled',
      'body':
          '$doctorName has cancelled your online consultation scheduled at $scheduledTime.',
      'metadata': {
        'consultationId': consultationId,
        'doctorName': doctorName,
        'scheduledTime': scheduledTime,
        'reason': reason,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Nurse overrides triage → notify patient ──────────────────────────────
  Future<void> notifyTriageOverride({
    required String patientId,
    required String oldLevel,
    required String newLevel,
    required String nurseName,
    required String reason,
  }) async {
    await _notifRef(patientId).add({
      'type': NotificationType.triageOverride.name,
      'title': 'Triage Level Updated',
      'body':
          'Your triage level has been changed from $oldLevel to $newLevel by $nurseName.',
      'metadata': {
        'oldLevel': oldLevel,
        'newLevel': newLevel,
        'nurseName': nurseName,
        'reason': reason,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Queue position update → notify patient ───────────────────────────────
  Future<void> notifyQueueUpdate({
    required String patientId,
    required int position,
    required int estimatedWaitMinutes,
  }) async {
    await _notifRef(patientId).add({
      'type': NotificationType.queueUpdate.name,
      'title': 'Queue Update',
      'body':
          'You are now #$position in the queue. Estimated wait: $estimatedWaitMinutes min.',
      'metadata': {
        'position': position,
        'estimatedWaitMinutes': estimatedWaitMinutes,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCTOR-FACING NOTIFICATIONS  (patient → doctor)
  // ══════════════════════════════════════════════════════════════════════════

  // ─── Patient cancels appointment → notify doctor ──────────────────────────
  Future<void> notifyDoctorAppointmentCancelled({
    required String doctorId,
    required String appointmentId,
    required String patientName,
    required String appointmentDate,
  }) async {
    await _notifRef(doctorId).add({
      'type': NotificationType.appointmentCancelled.name,
      'title': 'Appointment Cancelled by Patient',
      'body':
          '$patientName has cancelled their appointment on $appointmentDate.',
      'metadata': {
        'appointmentId': appointmentId,
        'patientName': patientName,
        'appointmentDate': appointmentDate,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Patient cancels consultation → notify doctor ─────────────────────────
  Future<void> notifyDoctorConsultationCancelled({
    required String doctorId,
    required String consultationId,
    required String patientName,
    required String scheduledTime,
  }) async {
    await _notifRef(doctorId).add({
      'type': NotificationType.consultationCancelled.name,
      'title': 'Consultation Cancelled by Patient',
      'body':
          '$patientName has cancelled their online consultation scheduled at $scheduledTime.',
      'metadata': {
        'consultationId': consultationId,
        'patientName': patientName,
        'scheduledTime': scheduledTime,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsRead(String userId, String notificationId) async {
    await _notifRef(userId).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap =
        await _notifRef(userId).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _notifRef(userId).doc(notificationId).delete();
  }
}
