import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/triage_levels.dart';
import 'encryption_service.dart';

enum NotificationType {
  appointmentCancelled,
  consultationCancelled,
  triageOverride,
  queueUpdate,
  patientArrival,
  reminder,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String titleAr;
  final String bodyAr;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.titleAr = '',
    this.bodyAr = '',
    required this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? title,
    String? body,
    String? titleAr,
    String? bodyAr,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title ?? this.title,
      body: body ?? this.body,
      titleAr: titleAr ?? this.titleAr,
      bodyAr: bodyAr ?? this.bodyAr,
      metadata: metadata,
      isRead: isRead,
      createdAt: createdAt,
    );
  }

  String localizedTitle(bool isArabic) =>
      isArabic && titleAr.isNotEmpty ? titleAr : title;

  String localizedBody(bool isArabic) =>
      isArabic && bodyAr.isNotEmpty ? bodyAr : body;

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
      titleAr: data['titleAr'] ?? '',
      bodyAr: data['bodyAr'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationService {
  final FirebaseFirestore _firestore;

  /// [firestore] is injectable for tests; production callers use the default
  /// live instance.
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _notifRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _notifRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final raw =
              snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
          final decrypted = await Future.wait(raw.map((n) async {
            if (':'.allMatches(n.title).length != 2) return n;
            try {
              final d = await EncryptionService.getDecryptedNotification(
                userId: userId,
                notificationId: n.id,
                fields: ['title', 'body', 'titleAr', 'bodyAr'],
              );
              return n.copyWith(
                title: d['title'] as String? ?? n.title,
                body: d['body'] as String? ?? n.body,
                titleAr: d['titleAr'] as String? ?? n.titleAr,
                bodyAr: d['bodyAr'] as String? ?? n.bodyAr,
              );
            } catch (_) {
              return n;
            }
          }));
          return decrypted;
        });
  }

  Stream<int> unreadCountStream(String userId) {
    return _notifRef(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PATIENT-FACING NOTIFICATIONS  (doctor/nurse → patient)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isNotificationsEnabled(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    return data?['notificationsEnabled'] as bool? ?? true;
  }

  Future<void> setNotificationsEnabled(String userId, bool enabled) async {
    await _firestore.collection('users').doc(userId).set({
      'notificationsEnabled': enabled,
    }, SetOptions(merge: true));
  }

  Future<void> notifyAppointmentCancelled({
    required String patientId,
    required String appointmentId,
    required String doctorName,
    required String appointmentDate,
    required String reason,
  }) async {
    if (!await isNotificationsEnabled(patientId)) return;
    await EncryptionService.saveNotification(
      userIds: [patientId],
      data: {
        'type': NotificationType.appointmentCancelled.name,
        'title': 'Appointment Cancelled',
        'body':
            '$doctorName has cancelled your appointment on $appointmentDate.',
        'titleAr': 'تم إلغاء الموعد',
        'bodyAr':
            'قام $doctorName بإلغاء موعدك بتاريخ $appointmentDate.',
        'metadata': {
          'appointmentId': appointmentId,
          'doctorName': doctorName,
          'appointmentDate': appointmentDate,
          'reason': reason,
        },
        'isRead': false,
      },
    );
  }

  Future<void> notifyConsultationCancelled({
    required String patientId,
    required String consultationId,
    required String doctorName,
    required String scheduledTime,
    required String reason,
    String consultationType = '',
  }) async {
    if (!await isNotificationsEnabled(patientId)) return;
    final typeLabel = _consultationTypeLabel(consultationType);
    final typeLabelAr = _consultationTypeLabelAr(consultationType);
    await EncryptionService.saveNotification(
      userIds: [patientId],
      data: {
        'type': NotificationType.consultationCancelled.name,
        'title': 'Consultation Cancelled',
        'body':
            '$doctorName has cancelled your $typeLabel consultation scheduled at $scheduledTime.',
        'titleAr': 'تم إلغاء الاستشارة',
        'bodyAr':
            'قام $doctorName بإلغاء استشارتك $typeLabelAr المحددة في $scheduledTime.',
        'metadata': {
          'consultationId': consultationId,
          'doctorName': doctorName,
          'scheduledTime': scheduledTime,
          'reason': reason,
          'consultationType': consultationType,
        },
        'isRead': false,
      },
    );
  }

  Future<void> notifyTriageOverride({
    required String patientId,
    required String oldLevel,
    required String newLevel,
    required String nurseName,
    required String reason,
  }) async {
    if (!await isNotificationsEnabled(patientId)) return;
    final oldAr = _triageLevelAr(oldLevel);
    final newAr = _triageLevelAr(newLevel);
    await EncryptionService.saveNotification(
      userIds: [patientId],
      data: {
        'type': NotificationType.triageOverride.name,
        'title': 'Triage Level Updated',
        'body':
            'Your triage level has been changed from $oldLevel to $newLevel by $nurseName.',
        'titleAr': 'تم تحديث مستوى الفرز',
        'bodyAr':
            'تم تغيير مستوى الفرز الخاص بك من $oldAr إلى $newAr بواسطة $nurseName.',
        'metadata': {
          'oldLevel': oldLevel,
          'newLevel': newLevel,
          'nurseName': nurseName,
          'reason': reason,
        },
        'isRead': false,
      },
    );
  }

  /// [bodyOverride]/[bodyArOverride] let a caller (e.g. the position fan-out)
  /// supply a precomputed message — including a wait-time range — instead of the
  /// default position/minutes wording. When omitted, the default body is used.
  Future<void> notifyQueueUpdate({
    required String patientId,
    required int position,
    required int estimatedWaitMinutes,
    String? bodyOverride,
    String? bodyArOverride,
  }) async {
    if (!await isNotificationsEnabled(patientId)) return;
    final isBeingSeen = position <= 1;
    final isNext = position == 2;
    final title = isBeingSeen
        ? "It's Your Turn"
        : (isNext ? "You're Next" : 'Queue Update');
    final titleAr = isBeingSeen
        ? 'حان دورك'
        : (isNext ? 'أنت التالي' : 'تحديث الطابور');
    await EncryptionService.saveNotification(
      userIds: [patientId],
      data: {
        'type': NotificationType.queueUpdate.name,
        'title': title,
        'body': bodyOverride ??
            (isBeingSeen
                ? "It's your turn — you're being seen now."
                : isNext
                    ? "You're next — please be ready."
                    : 'You are now #$position in the queue. Estimated wait: $estimatedWaitMinutes min.'),
        'titleAr': titleAr,
        'bodyAr': bodyArOverride ??
            (isBeingSeen
                ? 'حان دورك — تتم رؤيتك الآن.'
                : isNext
                    ? 'أنت التالي — يرجى الاستعداد.'
                    : 'أنت الآن في المرتبة #$position في الطابور. وقت الانتظار المتوقع: $estimatedWaitMinutes دقيقة.'),
        'metadata': {
          'position': position,
          'estimatedWaitMinutes': estimatedWaitMinutes,
        },
        'isRead': false,
      },
    );
  }

  /// Broadcast to every staff user with role == 'nurse'.
  /// Called when a patient flips to waiting_nurse in arrival_checkin_screen.
  /// Best-effort — caller wraps in try/catch.
  Future<void> notifyNursePatientArrival({
    required String patientName,
    required String queueNumber,
    required bool reportedSymptoms,
  }) async {
    final nursesSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'nurse')
        .get();

    if (nursesSnap.docs.isEmpty) return;

    final symptomLine = reportedSymptoms
        ? 'They submitted a symptom report via the app.'
        : 'Manual check-in — no symptom report available.';
    final symptomLineAr = reportedSymptoms
        ? 'قدّم المريض تقرير أعراض عبر التطبيق.'
        : 'تسجيل وصول يدوي — لا يوجد تقرير أعراض.';

    final nurseIds = nursesSnap.docs.map((d) => d.id).toList();
    await EncryptionService.saveNotification(
      userIds: nurseIds,
      data: {
        'type': NotificationType.patientArrival.name,
        'title': 'New Patient Arrived',
        'body':
            '$patientName (#$queueNumber) is waiting for triage. $symptomLine',
        'titleAr': 'وصل مريض جديد',
        'bodyAr':
            '$patientName (#$queueNumber) في انتظار الفرز. $symptomLineAr',
        'metadata': {
          'patientName': patientName,
          'queueNumber': queueNumber,
          'reportedSymptoms': reportedSymptoms,
        },
        'isRead': false,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCTOR-FACING NOTIFICATIONS  (patient → doctor)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> notifyDoctorAppointmentCancelled({
    required String doctorId,
    required String appointmentId,
    required String patientName,
    required String appointmentDate,
  }) async {
    await EncryptionService.saveNotification(
      userIds: [doctorId],
      data: {
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
      },
    );
  }

  Future<void> notifyDoctorConsultationCancelled({
    required String doctorId,
    required String consultationId,
    required String patientName,
    required String scheduledTime,
  }) async {
    await EncryptionService.saveNotification(
      userIds: [doctorId],
      data: {
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
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsRead(String userId, String notificationId) async {
    await _notifRef(userId).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _notifRef(
      userId,
    ).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _notifRef(userId).doc(notificationId).delete();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static String _consultationTypeLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('video')) return 'video';
    if (t.contains('phone') || t.contains('call')) return 'phone';
    if (t.contains('text') || t.contains('chat')) return 'text';
    return 'online';
  }

  static String _consultationTypeLabelAr(String type) {
    final t = type.toLowerCase();
    if (t.contains('video')) return 'المرئية';
    if (t.contains('phone') || t.contains('call')) return 'الهاتفية';
    if (t.contains('text') || t.contains('chat')) return 'النصية';
    return 'الإلكترونية';
  }

  static String _triageLevelAr(String level) => TriageLevels.labelAr(level);
}
