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

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'body': body,
        'metadata': metadata,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Collection reference for a patient ───────────────────────────────────
  CollectionReference _notifRef(String patientId) => _firestore
    .collection('users')
    .doc(patientId)
    .collection('notifications');

  // ─── Stream: all notifications (newest first) ─────────────────────────────
  Stream<List<AppNotification>> notificationsStream(String patientId) {
    return _notifRef(patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppNotification.fromFirestore(d)).toList());
  }

  // ─── Stream: unread count only (for the badge) ────────────────────────────
  Stream<int> unreadCountStream(String patientId) {
    return _notifRef(patientId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ─── WRITE: Doctor cancels an appointment ─────────────────────────────────
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
      'body':
          '$doctorName has cancelled your appointment on $appointmentDate.',
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

  // ─── WRITE: Doctor cancels an online consultation ─────────────────────────
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

  // ─── WRITE: Nurse overrides triage level ──────────────────────────────────
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

  // ─── WRITE: Queue position update ─────────────────────────────────────────
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

  // ─── WRITE: General reminder ──────────────────────────────────────────────
  Future<void> notifyReminder({
    required String patientId,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    await _notifRef(patientId).add({
      'type': NotificationType.reminder.name,
      'title': title,
      'body': body,
      'metadata': metadata ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Mark one notification as read ────────────────────────────────────────
  Future<void> markAsRead(String patientId, String notificationId) async {
    await _notifRef(patientId).doc(notificationId).update({'isRead': true});
  }

  // ─── Mark all as read ─────────────────────────────────────────────────────
  Future<void> markAllAsRead(String patientId) async {
    final snap =
        await _notifRef(patientId).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── Delete one notification ──────────────────────────────────────────────
  Future<void> deleteNotification(
      String patientId, String notificationId) async {
    await _notifRef(patientId).doc(notificationId).delete();
  }
}