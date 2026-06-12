import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shown when a patient taps "I Have Arrived" and has an upcoming appointment
/// but no pending triage in the queue.
///
/// Displays appointment confirmation, doctor details, where to go, and a
/// contextual pre-visit checklist derived from the department. Confirms the
/// patient's arrival by writing `status = 'patient_arrived'` on the appointment
/// document.
class AppointmentArrivalScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const AppointmentArrivalScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<AppointmentArrivalScreen> createState() =>
      _AppointmentArrivalScreenState();
}

class _AppointmentArrivalScreenState extends State<AppointmentArrivalScreen> {
  bool _confirming = false;
  bool _confirmed = false;

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  Future<void> _confirmArrival() async {
    setState(() => _confirming = true);
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
            'status': 'patient_arrived',
            'arrivedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) setState(() => _confirmed = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'فشل تسجيل الوصول. يرجى المحاولة عند الاستقبال.'
                : 'Check-in failed. Please try at the reception desk.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.appointmentData;
    final doctorName = (d['doctorName'] as String?) ?? 'Your Doctor';
    final specialty = (d['doctorSpecialty'] as String?) ?? '';
    final department = (d['department'] as String?) ?? '';
    final hospital = (d['hospital'] as String?) ?? '';
    final date = (d['date'] as String?) ?? '';
    final time = (d['time'] as String?) ?? '';
    final reason = (d['reason'] as String?)?.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          isArabic ? 'وصلت لموعدي' : 'Appointment Check-In',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: _confirmed
            ? _buildSuccessState(doctorName, department, hospital)
            : _buildCheckInState(
                doctorName,
                specialty,
                department,
                hospital,
                date,
                time,
                reason,
              ),
      ),
    );
  }

  // ── Success state ────────────────────────────────────────────────────────────

  Widget _buildSuccessState(
    String doctorName,
    String department,
    String hospital,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade50,
                border: Border.all(color: Colors.teal.shade200, width: 3),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.teal.shade600,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isArabic ? 'تم تسجيل وصولك!' : "You're checked in!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'توجّه إلى استقبال $department. سيستدعيك الفريق الطبي قريباً.'
                  : 'Please head to the $department reception. The medical team will call you shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _infoCard(
              Icons.location_on_outlined,
              Colors.teal,
              isArabic ? 'إلى أين تذهب' : 'Where to go',
              isArabic
                  ? 'توجّه إلى قسم $department في $hospital وأبلغ موظف الاستقبال باسمك.'
                  : 'Head to the $department department at $hospital and give your name to the receptionist.',
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  isArabic ? 'العودة للرئيسية' : 'Back to Home',
                  style: const TextStyle(fontSize: 17, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Check-in state ───────────────────────────────────────────────────────────

  Widget _buildCheckInState(
    String doctorName,
    String specialty,
    String department,
    String hospital,
    String date,
    String time,
    String reason,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'مرحباً بك في ${hospital.isNotEmpty ? hospital : "المستشفى"}'
                      : 'Welcome to ${hospital.isNotEmpty ? hospital : "the hospital"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic ? 'موعدك مؤكد' : 'Your appointment is confirmed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Doctor card ──
          _sectionLabel(isArabic ? 'طبيبك' : 'Your Doctor'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(
                    Icons.person,
                    color: Colors.teal.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (specialty.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          specialty,
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (department.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          department,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Appointment details ──
          _sectionLabel(isArabic ? 'تفاصيل الموعد' : 'Appointment Details'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _detailRow(
                  Icons.calendar_today_outlined,
                  Colors.indigo,
                  isArabic ? 'التاريخ' : 'Date',
                  date,
                ),
                const Divider(height: 20),
                _detailRow(
                  Icons.access_time,
                  Colors.orange,
                  isArabic ? 'الوقت' : 'Time',
                  time,
                ),
                const Divider(height: 20),
                _detailRow(
                  Icons.local_hospital_outlined,
                  Colors.teal,
                  isArabic ? 'القسم' : 'Department',
                  department,
                ),
                const Divider(height: 20),
                _detailRow(
                  Icons.apartment_outlined,
                  Colors.blueGrey,
                  isArabic ? 'المستشفى' : 'Hospital',
                  hospital,
                ),
                if (reason.isNotEmpty) ...[
                  const Divider(height: 20),
                  _detailRow(
                    Icons.notes_outlined,
                    Colors.purple,
                    isArabic ? 'السبب' : 'Reason',
                    reason,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Where to go ──
          _sectionLabel(isArabic ? 'إلى أين تذهب' : 'Where to Go'),
          const SizedBox(height: 10),
          _infoCard(
            Icons.location_on_outlined,
            Colors.teal,
            isArabic ? 'الاستقبال' : 'Reception',
            isArabic
                ? 'توجّه مباشرةً إلى استقبال $department في $hospital. أبلغ موظف الاستقبال باسمك ورقم موعدك.'
                : 'Head directly to the $department reception at $hospital. Give the receptionist your name and appointment details.',
          ),
          const SizedBox(height: 10),
          _infoCard(
            Icons.schedule_outlined,
            Colors.orange,
            isArabic ? 'الوصول المبكر' : 'Arrive Early',
            isArabic
                ? 'يُنصح بالوصول قبل موعدك بـ 10–15 دقيقة لإتمام الإجراءات.'
                : 'Please arrive 10–15 minutes before your appointment to complete any paperwork.',
          ),

          const SizedBox(height: 20),

          // ── Pre-visit checklist ──
          _sectionLabel(isArabic ? 'ما تحتاج إحضاره' : 'What to Bring'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _preVisitChecklist(
                department,
                isArabic,
              ).map((item) => _checklistItem(item)).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // ── Confirm button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirming ? null : _confirmArrival,
              icon: _confirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.where_to_vote_outlined),
              label: Text(
                _confirming
                    ? (isArabic ? 'جارٍ التسجيل…' : 'Checking in…')
                    : (isArabic ? 'تأكيد الوصول' : 'Confirm Arrival'),
                style: const TextStyle(fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [
      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
    ],
  );

  Widget _detailRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(IconData icon, Color color, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.teal.shade600,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a contextual pre-visit checklist based on the department name.
  /// All lists start with the universal items every patient should bring.
  static List<String> _preVisitChecklist(String department, bool isArabic) {
    final dept = department.toLowerCase();

    if (isArabic) {
      final base = [
        'الهوية الإماراتية',
        'بطاقة التأمين الصحي / وثيقة التأمين',
        'قائمة الأدوية الحالية',
      ];
      if (dept.contains('cardio')) {
        return [
          ...base,
          'تجنّب الكافيين قبل ساعتين من الموعد',
          'ارتدِ ملابس مريحة وفضفاضة (لتخطيط القلب)',
          'نتائج فحوصات القلب السابقة إن وُجدت',
        ];
      }
      if (dept.contains('ophthalmol') ||
          dept.contains('eye') ||
          dept.contains('عيون')) {
        return [
          ...base,
          'رتّب وسيلة مواصلات للعودة (قد يتم توسيع حدقة العين)',
          'انزع العدسات اللاصقة قبل الزيارة',
        ];
      }
      if (dept.contains('ent') ||
          dept.contains('أنف') ||
          dept.contains('أذن')) {
        return [
          ...base,
          'تجنّب الأكل قبل ساعتين إن كان مقرراً إجراء منظار',
          'نتائج فحوصات السمع السابقة إن وُجدت',
        ];
      }
      if (dept.contains('ortho') || dept.contains('عظام')) {
        return [
          ...base,
          'صور الأشعة أو الرنين المغناطيسي السابقة',
          'ارتدِ ملابس مريحة تتيح الوصول للمنطقة المصابة',
        ];
      }
      if (dept.contains('derm') || dept.contains('جلد')) {
        return [
          ...base,
          'تجنّبي ارتداء المكياج على المنطقة المصابة',
          'صور للتغيرات الجلدية إن أمكن',
        ];
      }
      if (dept.contains('gastro') || dept.contains('هضمي')) {
        return [
          ...base,
          'قد يُطلب الصيام — راجع الكلينيك للتأكيد',
          'نتائج المناظير السابقة إن وُجدت',
        ];
      }
      if (dept.contains('neuro') || dept.contains('أعصاب')) {
        return [
          ...base,
          'نتائج الرنين المغناطيسي / الأشعة المقطعية / رسم الدماغ السابقة',
          'قائمة مفصّلة بالأدوية (بما فيها أدوية الصرع)',
        ];
      }
      if (dept.contains('pulmon') ||
          dept.contains('رئة') ||
          dept.contains('تنفس')) {
        return [
          ...base,
          'تجنّب التدخين قبل ساعتين من الموعد',
          'نتائج قياس وظائف الرئة السابقة إن وُجدت',
        ];
      }
      if (dept.contains('paed') || dept.contains('أطفال')) {
        return [...base, 'سجل التطعيمات', 'منحنى النمو إن توفّر'];
      }
      if (dept.contains('radiol') ||
          dept.contains('أشعة') ||
          dept.contains('mri') ||
          dept.contains('imaging')) {
        return [
          ...base,
          'انزع جميع المجوهرات والمعادن',
          'قد يُطلب الصيام — راجع الكلينيك للتأكيد',
          'صور الأشعة السابقة إن وُجدت',
        ];
      }
      if (dept.contains('dent') || dept.contains('أسنان')) {
        return [
          ...base,
          'نظّف أسنانك قبل الزيارة',
          'صور الأشعة السابقة لأسنانك إن وُجدت',
        ];
      }
      // Default
      return [
        ...base,
        'أي فحوصات أو تقارير طبية سابقة',
        'خطاب إحالة من الطبيب العام (إن طُلب)',
      ];
    }

    // English
    final base = [
      'Emirates ID',
      'Health insurance card / policy details',
      'List of all current medications',
    ];
    if (dept.contains('cardio')) {
      return [
        ...base,
        'Avoid caffeine at least 2 hours before your visit',
        'Wear loose, comfortable clothing (for ECG if needed)',
        'Previous cardiac test results or reports',
      ];
    }
    if (dept.contains('ophthalmol') || dept.contains('eye')) {
      return [
        ...base,
        'Arrange a ride home — your pupils may be dilated after the exam',
        'Remove contact lenses before your appointment',
      ];
    }
    if (dept.contains('ent')) {
      return [
        ...base,
        'Avoid eating 2 hours before if a scope procedure is scheduled',
        'Previous hearing or throat examination results',
      ];
    }
    if (dept.contains('ortho')) {
      return [
        ...base,
        'Any previous X-rays, MRI, or CT scans of the affected area',
        'Wear comfortable clothing that allows access to the affected area',
      ];
    }
    if (dept.contains('derm')) {
      return [
        ...base,
        'No makeup or nail polish on the affected area',
        'Photos of any skin changes you have noticed (if possible)',
      ];
    }
    if (dept.contains('gastro')) {
      return [
        ...base,
        'Fasting may be required — please confirm with the clinic',
        'Previous endoscopy or colonoscopy reports',
      ];
    }
    if (dept.contains('neuro')) {
      return [
        ...base,
        'Previous MRI, CT, or EEG results',
        'Detailed medication list (including any seizure medications)',
      ];
    }
    if (dept.contains('pulmon') || dept.contains('respir')) {
      return [
        ...base,
        'Avoid smoking at least 2 hours before your visit',
        'Previous pulmonary function test (spirometry) results',
      ];
    }
    if (dept.contains('paed')) {
      return [
        ...base,
        "Child's vaccination record",
        'Growth chart if available',
      ];
    }
    if (dept.contains('radiol') ||
        dept.contains('mri') ||
        dept.contains('imaging')) {
      return [
        ...base,
        'Remove all metal jewellery before your scan',
        'Fasting may be required — please confirm with the clinic',
        'Previous imaging results for comparison',
      ];
    }
    if (dept.contains('dent')) {
      return [
        ...base,
        'Brush and floss before your visit',
        'Previous dental X-rays if available',
      ];
    }
    // Default: internal medicine, family, general
    return [
      ...base,
      'Any previous medical reports, lab results, or test results',
      'GP referral letter (if required by the specialist)',
    ];
  }
}
