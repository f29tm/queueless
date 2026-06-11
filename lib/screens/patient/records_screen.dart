
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/encryption_service.dart';
import '../../services/notification_service.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool showAppointments = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user logged in")));
    }

   final isArabic = Localizations.localeOf(context).languageCode == 'ar';

return Directionality(
  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
  child: Scaffold(
  backgroundColor: const Color(0xFFF5F7FA),
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          Text(
            isArabic ? "سجلاتي" : "My Records",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            isArabic
                ? "مواعيدك واستشاراتك"
                : "Your appointments and consultations",
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 24),

          _buildTabs(user.uid),

          const SizedBox(height: 22),

          Expanded(
            child: showAppointments
                ? _buildAppointmentsTab(user.uid)
                : _buildConsultationsTab(user.uid),
          ),
        ],
      ),
    ),
  ),
  ),
);
  }

Widget _buildTabs(String uid) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  return StreamBuilder<List<int>>(
    stream: _combinedCounts(uid),
    builder: (context, snapshot) {
      final counts = snapshot.data ?? [0, 0];
      final appointmentCount = counts[0];
      final consultationCount = counts[1];

      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: _tabButton(
                selected: showAppointments,
                icon: Icons.calendar_today_outlined,
                title: isArabic ? "المواعيد" : "Appointments",
                badgeCount: appointmentCount,
                onTap: () => setState(() => showAppointments = true),
              ),
            ),
            Expanded(
              child: _tabButton(
                selected: !showAppointments,
                icon: Icons.medical_information_outlined,
                title: isArabic ? "الاستشارات" : "Consultations",
                badgeCount: consultationCount,
                onTap: () => setState(() => showAppointments = false),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Stream<List<int>> _combinedCounts(String uid) async* {
    await for (final appointmentsSnapshot in FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .snapshots()) {
      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: uid)
          .get();

      yield [
        appointmentsSnapshot.docs.length,
        consultationsSnapshot.docs.length,
      ];
    }
  }

  Widget _tabButton({
    required bool selected,
    required IconData icon,
    required String title,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF0F8B8D)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF0F8B8D)
                    : const Color(0xFF6B7280),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$badgeCount",
                  style: const TextStyle(
                    color: Color(0xFF0F8B8D),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F8B8D)),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<QueryDocumentSnapshot> docs =
            List.from(snapshot.data?.docs ?? []);

        docs.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) return _buildEmptyAppointments();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _AppointmentCard(
                appointmentId: docs[index].id, data: data);
          },
        );
      },
    );
  }

  Widget _buildConsultationsTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F8B8D)),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<QueryDocumentSnapshot> docs =
            List.from(snapshot.data?.docs ?? []);

        docs.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) return _buildEmptyConsultations();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _ConsultationCard(
                consultationId: docs[index].id, data: data);
          },
        );
      },
    );
  }
Widget _buildEmptyAppointments() {
  final isArabic =
      Localizations.localeOf(context).languageCode == 'ar';

  return Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 62,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 18),

          Text(
            isArabic
                ? "لا توجد مواعيد حالياً"
                : "No appointments yet",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isArabic
                ? "ستظهر مواعيدك المحجوزة هنا"
                : "Your booked appointments will appear here",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyConsultations() {
  final isArabic =
      Localizations.localeOf(context).languageCode == 'ar';

  return Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 58,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 18),

          Text(
            isArabic
                ? "لا توجد استشارات حالياً"
                : "No consultations yet",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isArabic
                ? "ستظهر استشاراتك المكتملة هنا"
                : "Your completed consultations will appear here",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ── Cancel dialog + notify doctor ─────────────────────────────────────────────
Future<void> _confirmCancelRecord({
  required BuildContext context,
  required String collection,
  required String docId,
  required String itemType,
  required String doctorId,
  required String patientName,
  required String scheduledDate,
  required String scheduledTime,
  required bool isArabic,
}) async {
  final String dialogTitle = isArabic
      ? (itemType == 'appointment' ? 'إلغاء الموعد' : 'إلغاء الاستشارة')
      : 'Cancel $itemType';

  final String dialogBody = isArabic
      ? (itemType == 'appointment'
          ? 'هل أنت متأكد من إلغاء هذا الموعد؟ سيتم إشعار الطبيب.'
          : 'هل أنت متأكد من إلغاء هذه الاستشارة؟ سيتم إشعار الطبيب.')
      : 'Are you sure you want to cancel this $itemType? The doctor will be notified.';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(dialogTitle),
          content: Text(dialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isArabic ? 'لا' : 'No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F8B8D),
              ),
              child: Text(
                isArabic ? 'تأكيد' : 'Confirm',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    },
  );

  if (confirmed != true) return;

  // ── Update Firestore status ──────────────────────────────────────────────
  await FirebaseFirestore.instance.collection(collection).doc(docId).update({
    'status': 'cancelled',
    'cancelledBy': 'patient',
    'cancelledAt': FieldValue.serverTimestamp(),
  });

  // ── Notify the doctor ────────────────────────────────────────────────────
  if (doctorId.isNotEmpty) {
    final dateTime = '$scheduledDate at $scheduledTime';

    if (collection == 'appointments') {
      await NotificationService().notifyDoctorAppointmentCancelled(
        doctorId: doctorId,
        appointmentId: docId,
        patientName: patientName,
        appointmentDate: dateTime,
      );
    } else {
      await NotificationService().notifyDoctorConsultationCancelled(
        doctorId: doctorId,
        consultationId: docId,
        patientName: patientName,
        scheduledTime: dateTime,
      );
    }
  }

  if (context.mounted) {
    final snackMsg = isArabic
        ? (itemType == 'appointment' ? 'تم إلغاء الموعد' : 'تم إلغاء الاستشارة')
        : '${itemType[0].toUpperCase()}${itemType.substring(1)} cancelled';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackMsg)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _AppointmentCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const _AppointmentCard({
    required this.appointmentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final DateTime bookedAt = createdAt?.toDate() ?? DateTime.now();

    final String hospital = (data['hospital'] ?? 'Dubai Hospital').toString();
    final String department =
        (data['department'] ?? 'General Medicine').toString();
    final String doctorName = (data['doctorName'] ?? 'Doctor').toString();
    final String doctorId = (data['doctorUid'] ?? '').toString();
    final String reason = (data['reason'] ?? '').toString();
    final String status = (data['status'] ?? 'scheduled').toString();
    final String date = (data['date'] ?? 'Thu, Feb 26').toString();
    final String time = (data['time'] ?? '04:00 PM').toString();
    final String patientId = (data['patientId'] ?? '').toString();

    final String displayHospital =
        isArabic ? _translateHospital(hospital) : hospital;
    final String displayDepartment =
        isArabic ? _translateDepartment(department) : department;
    final String displayReason = isArabic ? _translateReason(reason) : reason;
    final String displayTime = isArabic ? _translateTime(time) : time;
    final String displayDate =
        isArabic ? _translateAppointmentDate(date) : date;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(patientId).get(),
        FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
      ]),
      builder: (context, snapshot) {
        final patientData =
            snapshot.data?[0].data() as Map<String, dynamic>?;
        final doctorData =
            snapshot.data?[1].data() as Map<String, dynamic>?;

        final patientName = patientData?['name'] as String? ?? 'Patient';

        final rawDoctorName = isArabic
            ? (doctorData?['nameAr'] ?? doctorData?['name'] ?? doctorName).toString()
            : (doctorData?['name'] ?? doctorName).toString();
        final displayDoctorName = isArabic
            ? rawDoctorName.replaceAll('Dr.', 'د.').replaceAll('Dr ', 'د. ')
            : rawDoctorName;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayHospital,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _statusBadge(_formatStatus(status, isArabic)),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    size: 18,
                    color: Color(0xFF0F8B8D),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayDepartment,
                    style: const TextStyle(
                      color: Color(0xFF0F8B8D),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Wrap(
                alignment: WrapAlignment.start,
                spacing: 16,
                runSpacing: 10,
                children: [
                  _infoItem(
                    icon: Icons.calendar_today_outlined,
                    text: displayDate,
                    isArabic: isArabic,
                  ),
                  _infoItem(
                    icon: Icons.access_time_outlined,
                    text: displayTime,
                    isArabic: isArabic,
                  ),
                  _infoItem(
                    icon: Icons.person_outline,
                    text: displayDoctorName,
                    isArabic: isArabic,
                  ),
                ],
              ),

              if (reason.isNotEmpty) ...[
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? "السبب" : "REASON",
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayReason,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      isArabic
                          ? "تم الحجز ${_formatBookedDate(bookedAt, isArabic)}"
                          : "Booked ${_formatBookedDate(bookedAt, isArabic)}",
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (status.toLowerCase() == 'scheduled')
                    IconButton(
                      onPressed: () async {
                        await _confirmCancelRecord(
                          context: context,
                          collection: 'appointments',
                          docId: appointmentId,
                          itemType: 'appointment',
                          doctorId: doctorId,
                          patientName: patientName,
                          scheduledDate: date,
                          isArabic: isArabic,
                          scheduledTime: time,
                        );
                      },
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 10, color: Color(0xFF0F8B8D)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F8B8D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String text,
    required bool isArabic,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _formatStatus(String status, bool isArabic) {
    switch (status.toLowerCase()) {
      case 'completed':
        return isArabic ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return isArabic ? 'ملغي' : 'Cancelled';
      default:
        return isArabic ? 'مجدول' : 'Scheduled';
    }
  }

  String _formatBookedDate(DateTime dt, bool isArabic) {
    const enMonths = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];

    const arMonths = [
      "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    ];

    return isArabic
        ? "${dt.day} ${arMonths[dt.month - 1]} ${dt.year}"
        : "${enMonths[dt.month - 1]} ${dt.day}, ${dt.year}";
  }

  String _translateHospital(String value) {
    switch (value.toLowerCase()) {
      case 'nmc royal hospital khalifa city, abu dhabi':
        return 'مستشفى إن إم سي رويال خليفة سيتي، أبوظبي';
      case 'nmc specialty hospital, al ain':
        return 'مستشفى إن إم سي التخصصي، العين';
      case 'nmc specialty hospital, abu dhabi':
        return 'مستشفى إن إم سي التخصصي، أبوظبي';
      case 'nmc royal hospital sharjah':
        return 'مستشفى إن إم سي رويال، الشارقة';
      case 'dubai hospital':
        return 'مستشفى دبي';
      default:
        return value;
    }
  }

  String _translateDepartment(String value) {
    switch (value.toLowerCase()) {
      case 'emergency medicine':
        return 'طب الطوارئ';
      case 'cardiology':
        return 'أمراض القلب';
      case 'dermatology':
        return 'الأمراض الجلدية';
      case 'ent':
        return 'الأنف والأذن والحنجرة';
      case 'internal medicine':
        return 'الطب الباطني';
      case 'ophthalmology':
        return 'طب العيون';
      case 'gastroenterology':
        return 'أمراض الجهاز الهضمي';
      case 'neuroscience':
        return 'علوم الأعصاب';
      case 'paediatrics':
      case 'pediatrics':
        return 'طب الأطفال';
      case 'pulmonology':
        return 'أمراض الرئة';
      case 'dentistry':
        return 'طب الأسنان';
      case 'family medicine':
        return 'طب الأسرة';
      case 'orthopaedics':
      case 'orthopedics':
        return 'العظام';
      case 'general medicine':
        return 'الطب العام';
      default:
        return value;
    }
  }

  String _translateReason(String value) {
    switch (value.toLowerCase()) {
      case 'regular check up':
      case 'regular checkup':
        return 'فحص طبي دوري';
      case 'general consultation':
        return 'استشارة عامة';
      default:
        return value;
    }
  }

  String _translateAppointmentDate(String value) {
    return value
        .replaceAll('Sat', 'السبت')
        .replaceAll('Sun', 'الأحد')
        .replaceAll('Mon', 'الاثنين')
        .replaceAll('Tue', 'الثلاثاء')
        .replaceAll('Wed', 'الأربعاء')
        .replaceAll('Thu', 'الخميس')
        .replaceAll('Fri', 'الجمعة')
        .replaceAll('Jan', 'يناير')
        .replaceAll('Feb', 'فبراير')
        .replaceAll('Mar', 'مارس')
        .replaceAll('Apr', 'أبريل')
        .replaceAll('May', 'مايو')
        .replaceAll('Jun', 'يونيو')
        .replaceAll('Jul', 'يوليو')
        .replaceAll('Aug', 'أغسطس')
        .replaceAll('Sep', 'سبتمبر')
        .replaceAll('Oct', 'أكتوبر')
        .replaceAll('Nov', 'نوفمبر')
        .replaceAll('Dec', 'ديسمبر');
  }

  String _translateTime(String value) {
    return value.replaceAll('AM', 'صباحاً').replaceAll('PM', 'مساءً');
  }
}

/// ══════════════════════════════════════════════════════════════════════════════
//  CONSULTATION CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ConsultationCard extends StatelessWidget {
  final String consultationId;
  final Map<String, dynamic> data;

  const _ConsultationCard({
    required this.consultationId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final DateTime bookedAt = createdAt?.toDate() ?? DateTime.now();

    final String type = (data['consultationType'] ?? 'Video Call').toString();
    final String doctorName =
        (data['doctorName'] ?? 'Doctor').toString();
    final String doctorId = (data['doctorUid'] ?? '').toString();
    final String notes = (data['notes'] ?? '').toString();
    final String status = (data['status'] ?? 'scheduled').toString();
    final String date = (data['date'] ?? 'Thu, Feb 26').toString();
    final String time = (data['time'] ?? '04:00 PM').toString();
    final String patientId = (data['patientId'] ?? '').toString();

    final String displayType = isArabic ? _translateType(type) : type;
    final String displayNotes = isArabic ? _translateNotes(notes) : notes;
    final String displayDate = isArabic ? _translateAppointmentDate(date) : date;
    final String displayTime = isArabic ? _translateTime(time) : time;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(patientId).get(),
        FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
      ]),
      builder: (context, snapshot) {
        final patientData =
            snapshot.data?[0].data() as Map<String, dynamic>?;

        final doctorData =
            snapshot.data?[1].data() as Map<String, dynamic>?;

        final patientName =
            patientData?['name'] as String? ?? 'Patient';

        final rawDoctorName = isArabic
            ? (doctorData?['nameAr'] ?? doctorData?['name'] ?? doctorName).toString()
            : (doctorData?['name'] ?? doctorName).toString();
        final displayDoctorName = isArabic
            ? rawDoctorName.replaceAll('Dr.', 'د.').replaceAll('Dr ', 'د. ')
            : rawDoctorName;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isArabic ? "استشارة إلكترونية" : "Online Consultation",
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _statusBadge(_formatStatus(status, isArabic)),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.video_call_outlined,
                    size: 18,
                    color: Color(0xFF0F8B8D),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayType,
                    style: const TextStyle(
                      color: Color(0xFF0F8B8D),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Wrap(
                alignment: WrapAlignment.start,
                spacing: 16,
                runSpacing: 10,
                children: [
                  _infoItem(
                    icon: Icons.calendar_today_outlined,
                    text: displayDate,
                    isArabic: isArabic,
                  ),
                  _infoItem(
                    icon: Icons.access_time_outlined,
                    text: displayTime,
                    isArabic: isArabic,
                  ),
                  _infoItem(
                    icon: Icons.person_outline,
                    text: displayDoctorName,
                    isArabic: isArabic,
                  ),
                ],
              ),

              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? "الملاحظات" : "NOTES",
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<String>(
                        future: (':'.allMatches(notes).length == 2)
                            ? EncryptionService.getDecryptedData(
                                collection: 'consultations',
                                docId: consultationId,
                                fields: ['notes'],
                              ).then((d) {
                                final dec = (d['notes'] as String?) ?? notes;
                                return isArabic ? _translateNotes(dec) : dec;
                              })
                            : Future.value(displayNotes),
                        builder: (_, snap) => Text(
                          snap.data ?? displayNotes,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      isArabic
                          ? "تم الحجز ${_formatBookedDate(bookedAt, isArabic)}"
                          : "Booked ${_formatBookedDate(bookedAt, isArabic)}",
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (status.toLowerCase() == 'scheduled')
                    IconButton(
                      onPressed: () async {
                        await _confirmCancelRecord(
                          context: context,
                          collection: 'consultations',
                          docId: consultationId,
                          itemType: 'consultation',
                          doctorId: doctorId,
                          patientName: patientName,
                          scheduledDate: date,
                          isArabic: isArabic,
                          scheduledTime: time,
                        );
                      },
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 10, color: Color(0xFF0F8B8D)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F8B8D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String text,
    required bool isArabic,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _formatStatus(String status, bool isArabic) {
    switch (status.toLowerCase()) {
      case 'completed':
        return isArabic ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return isArabic ? 'ملغي' : 'Cancelled';
      default:
        return isArabic ? 'مجدول' : 'Scheduled';
    }
  }

  String _formatBookedDate(DateTime dt, bool isArabic) {
    const enMonths = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];

    const arMonths = [
      "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    ];

    return isArabic
        ? "${dt.day} ${arMonths[dt.month - 1]} ${dt.year}"
        : "${enMonths[dt.month - 1]} ${dt.day}, ${dt.year}";
  }

  String _translateType(String value) {
    switch (value.toLowerCase()) {
      case 'video call':
        return 'مكالمة فيديو';
      case 'phone call':
        return 'مكالمة هاتفية';
      case 'voice call':
        return 'مكالمة صوتية';
      case 'text chat':
      case 'chat':
        return 'محادثة نصية';
      default:
        return value;
    }
  }

  String _translateNotes(String value) {
    switch (value.toLowerCase()) {
      case 'general consultation':
        return 'استشارة عامة';
      case 'follow up':
      case 'follow-up':
        return 'متابعة طبية';
      default:
        return value;
    }
  }

  String _translateAppointmentDate(String value) {
    return value
        .replaceAll('Sat', 'السبت')
        .replaceAll('Sun', 'الأحد')
        .replaceAll('Mon', 'الاثنين')
        .replaceAll('Tue', 'الثلاثاء')
        .replaceAll('Wed', 'الأربعاء')
        .replaceAll('Thu', 'الخميس')
        .replaceAll('Fri', 'الجمعة')
        .replaceAll('Jan', 'يناير')
        .replaceAll('Feb', 'فبراير')
        .replaceAll('Mar', 'مارس')
        .replaceAll('Apr', 'أبريل')
        .replaceAll('May', 'مايو')
        .replaceAll('Jun', 'يونيو')
        .replaceAll('Jul', 'يوليو')
        .replaceAll('Aug', 'أغسطس')
        .replaceAll('Sep', 'سبتمبر')
        .replaceAll('Oct', 'أكتوبر')
        .replaceAll('Nov', 'نوفمبر')
        .replaceAll('Dec', 'ديسمبر');
  }

  String _translateTime(String value) {
    return value.replaceAll('AM', 'صباحاً').replaceAll('PM', 'مساءً');
  }
}