import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OnlineConsultationScreen extends StatefulWidget {
  const OnlineConsultationScreen({super.key});

  @override
  State<OnlineConsultationScreen> createState() =>
      _OnlineConsultationScreenState();
}

class _OnlineConsultationScreenState extends State<OnlineConsultationScreen> {
  int currentStep = 0;
  bool isSaving = false;

  String? selectedType;
  String? selectedDoctor;
  String? selectedDoctorUid;
  String? selectedDoctorDepartment;
  String? selectedDoctorSpecialty;
  String? selectedDate;
  String? selectedTime;

  Set<String> bookedSlots = {};
  bool loadingSlots = false;

  final TextEditingController notesController = TextEditingController();

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String tr(String en, String ar) => isArabic ? ar : en;

  final List<Map<String, dynamic>> consultationTypes = [
    {
      "title": "Video Call",
      "subtitle": "Face-to-face with a doctor via video",
      "icon": Icons.videocam_outlined,
    },
    {
      "title": "Phone Call",
      "subtitle": "Speak with a doctor over the phone",
      "icon": Icons.call_outlined,
    },
    {
      "title": "Text Chat",
      "subtitle": "Message a doctor in real time",
      "icon": Icons.chat_bubble_outline,
    },
  ];

  late final List<String> availableDates = List.generate(
    4,
    (index) => DateFormat('EEE, MMM d').format(
      DateTime.now().add(Duration(days: index)),
    ),
  );

  final List<String> availableTimes = [
    "09:00 AM",
    "11:00 AM",
    "01:00 PM",
    "04:00 PM",
  ];

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String translateConsultationType(String value) {
    if (!isArabic) return value;

    switch (value.toLowerCase()) {
      case 'video call':
        return 'مكالمة فيديو';
      case 'phone call':
        return 'مكالمة هاتفية';
      case 'text chat':
        return 'محادثة نصية';
      default:
        return value;
    }
  }

  String translateConsultationSubtitle(String value) {
    if (!isArabic) return value;

    switch (value.toLowerCase()) {
      case 'face-to-face with a doctor via video':
        return 'تحدث مع الطبيب عبر الفيديو';
      case 'speak with a doctor over the phone':
        return 'تحدث مع الطبيب عبر الهاتف';
      case 'message a doctor in real time':
        return 'راسل الطبيب مباشرة';
      default:
        return value;
    }
  }

  String translateDoctorName(String name) {
    if (!isArabic) return name;

    String result = name;
    result = result.replaceAll('Dr.', 'د.');
    result = result.replaceAll('Dr ', 'د. ');
    return result;
  }

  String translateDepartment(String department) {
    if (!isArabic) return department;

    switch (department.toLowerCase()) {
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
        return department;
    }
  }

  String translateDoctorSpecialty(String specialty) {
    if (!isArabic) return specialty;

    switch (specialty.toLowerCase()) {
      case 'consultant emergency medicine':
        return 'استشاري طب الطوارئ';
      case 'chair of emergency medicine':
        return 'رئيس قسم طب الطوارئ';
      case 'emergency medicine':
        return 'طب الطوارئ';
      case 'cardiology':
        return 'أمراض القلب';
      case 'gastroenterology':
        return 'أمراض الجهاز الهضمي';
      case 'internal medicine':
        return 'الطب الباطني';
      case 'general medicine':
        return 'الطب العام';
      default:
        return specialty;
    }
  }

  String translateDate(String value) {
    if (!isArabic) return value;

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

  String translateTime(String value) {
    if (!isArabic) return value;
    return value.replaceAll('AM', 'صباحاً').replaceAll('PM', 'مساءً');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime _parseDateTime(String dateLabel, String timeLabel) {
    final datePart = dateLabel.split(',').last.trim();
    final date = DateFormat('MMM d').parse(datePart);
    final time = DateFormat('hh:mm a').parse(timeLabel);
    final now = DateTime.now();

    final year = (date.month < now.month ||
            (date.month == now.month && date.day < now.day))
        ? now.year + 1
        : now.year;

    return DateTime(year, date.month, date.day, time.hour, time.minute);
  }

  bool _isSelectedConsultationInPast() {
    if (selectedDate == null || selectedTime == null) return false;
    return _parseDateTime(selectedDate!, selectedTime!).isBefore(DateTime.now());
  }

  Future<void> _loadBookedSlots(String doctorUid) async {
    setState(() => loadingSlots = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('consultations')
          .where('doctorUid', isEqualTo: doctorUid)
          .where('status', isEqualTo: 'scheduled')
          .get();

      final slots = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        final time = data['time'] as String?;

        if (date != null && time != null) {
          slots.add('${doctorUid}_${date}_$time');
        }
      }

      setState(() {
        bookedSlots = slots;
        loadingSlots = false;
      });
    } catch (_) {
      setState(() => loadingSlots = false);
    }
  }

  bool _isSlotBooked(String time) {
    if (selectedDoctorUid == null || selectedDate == null) return false;
    return bookedSlots.contains('${selectedDoctorUid}_${selectedDate}_$time');
  }

  Future<void> _confirmConsultation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack(tr("No logged in user found.", "لا يوجد مستخدم مسجل الدخول."));
      return;
    }

    if (selectedType == null ||
        selectedDoctorUid == null ||
        selectedDate == null ||
        selectedTime == null) {
      _showSnack(tr(
        "Please complete all consultation steps.",
        "يرجى إكمال جميع خطوات الاستشارة.",
      ));
      return;
    }

    if (_isSelectedConsultationInPast()) {
      _showSnack(tr(
        "Selected consultation time has already passed.",
        "وقت الاستشارة المحدد قد مضى بالفعل.",
      ));
      return;
    }

    setState(() => isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final consultationRef = db.collection('consultations').doc();

      await db.runTransaction((transaction) async {
        final existingSnap = await db
            .collection('consultations')
            .where('doctorUid', isEqualTo: selectedDoctorUid)
            .where('date', isEqualTo: selectedDate)
            .where('time', isEqualTo: selectedTime)
            .where('status', isEqualTo: 'scheduled')
            .get();

        if (existingSnap.docs.isNotEmpty) {
          throw Exception('SLOT_TAKEN');
        }

        final notes = notesController.text.trim();

        final consultationData = <String, dynamic>{
          'consultationId': consultationRef.id,
          'patientId': user.uid,
          'consultationType': selectedType,
          'doctorName': selectedDoctor,
          'doctorUid': selectedDoctorUid,
          'doctorDepartment': selectedDoctorDepartment,
          'doctorSpecialty': selectedDoctorSpecialty,
          'date': selectedDate,
          'time': selectedTime,
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (notes.isNotEmpty) {
          consultationData['notes'] = notes;
        }

        transaction.set(consultationRef, consultationData);
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            tr("Consultation Booked", "تم حجز الاستشارة"),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isArabic
                ? "تم تأكيد ${translateConsultationType(selectedType ?? '')} مع ${translateDoctorName(selectedDoctor ?? '')} بتاريخ ${translateDate(selectedDate ?? '')} الساعة ${translateTime(selectedTime ?? '')}."
                : "Your $selectedType with $selectedDoctor on $selectedDate at $selectedTime has been confirmed.",
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8B8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  tr("OK", "حسناً"),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } on Exception catch (e) {
      if (e.toString().contains('SLOT_TAKEN')) {
        if (selectedDoctorUid != null) {
          await _loadBookedSlots(selectedDoctorUid!);
        }

        setState(() => currentStep = 2);

        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                tr("Slot No Longer Available", "الموعد لم يعد متاحاً"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                tr(
                  "This time slot was just booked by another patient. Please select a different time.",
                  "تم حجز هذا الوقت من قبل مريض آخر. يرجى اختيار وقت مختلف.",
                ),
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F8B8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      tr("Choose Another Time", "اختيار وقت آخر"),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        _showSnack(tr("Booking failed: $e", "فشل الحجز: $e"));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void nextStep() {
    if (currentStep == 0 && selectedType == null) {
      _showSnack(tr(
        "Please select a consultation type.",
        "يرجى اختيار نوع الاستشارة.",
      ));
      return;
    }

    if (currentStep == 1 && selectedDoctorUid == null) {
      _showSnack(tr("Please select a doctor.", "يرجى اختيار الطبيب."));
      return;
    }

    if (currentStep == 2 && (selectedDate == null || selectedTime == null)) {
      _showSnack(tr(
        "Please select date and time.",
        "يرجى اختيار التاريخ والوقت.",
      ));
      return;
    }

    if (currentStep == 2 && _isSelectedConsultationInPast()) {
      _showSnack(tr(
        "Selected consultation time has already passed.",
        "وقت الاستشارة المحدد قد مضى بالفعل.",
      ));
      return;
    }

    if (currentStep == 2 && _isSlotBooked(selectedTime!)) {
      _showSnack(tr(
        "This slot is already booked. Please choose another.",
        "هذا الموعد محجوز بالفعل. يرجى اختيار موعد آخر.",
      ));
      return;
    }

    if (currentStep < 3) {
      setState(() => currentStep++);
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Directionality(
          textDirection: Directionality.of(context),
          child: Column(
            children: [
              _buildHeader(),
              _buildProgress(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: _buildStepContent(),
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Center(
        child: Text(
          tr("Online Consultation", "استشارة إلكترونية"),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final active = index <= currentStep;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0F8B8D) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _buildTypeStep();
      case 1:
        return _buildDoctorStep();
      case 2:
        return _buildDateTimeStep();
      case 3:
        return _buildSummaryStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr("Online Consultation", "استشارة إلكترونية"),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            "Connect with a healthcare professional from anywhere",
            "تواصل مع طبيب مختص من أي مكان",
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 22),
        Text(
          tr("Consultation Type", "نوع الاستشارة"),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 16),
        ...consultationTypes.map(
          (type) => _selectCard(
            title: translateConsultationType(type["title"]),
            subtitle: translateConsultationSubtitle(type["subtitle"]),
            icon: type["icon"],
            selected: selectedType == type["title"],
            onTap: () => setState(() => selectedType = type["title"]),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorStep() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic
                  ? "حدث خطأ أثناء تحميل الأطباء: ${snapshot.error}"
                  : "Error loading doctors: ${snapshot.error}",
              style: const TextStyle(fontSize: 15, color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<String, QueryDocumentSnapshot> uniqueDoctors = {};

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = (data['uid'] ?? doc.id).toString();

          if (uid.isNotEmpty) {
            uniqueDoctors[uid] = doc;
          }
        }

        final doctors = uniqueDoctors.values.toList();

        if (doctors.isEmpty) {
          return Center(
            child: Text(
              tr("No doctors found.", "لا يوجد أطباء حالياً."),
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        return Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              tr("Select Doctor", "اختر الطبيب"),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                "Choose a doctor for your consultation",
                "اختر الطبيب المناسب للاستشارة",
              ),
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 22),
            ...doctors.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final doctorName = (data['name'] ?? 'Doctor').toString();
              final specialty = (data['specialty'] ?? '').toString();
              final department = (data['department'] ?? '').toString();
              final uid = (data['uid'] ?? doc.id).toString();

              return _selectCard(
                title: translateDoctorName(doctorName),
                subtitle:
                    "${translateDepartment(department)} • ${translateDoctorSpecialty(specialty)}",
                icon: Icons.person_outline,
                selected: selectedDoctorUid == uid,
                onTap: () async {
                  setState(() {
                    selectedDoctor = doctorName;
                    selectedDoctorUid = uid;
                    selectedDoctorDepartment = department;
                    selectedDoctorSpecialty = specialty;
                    selectedDate = null;
                    selectedTime = null;
                  });

                  await _loadBookedSlots(uid);
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDateTimeStep() {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr("Select Date & Time", "اختر التاريخ والوقت"),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            "Choose your preferred consultation slot",
            "اختر وقت الاستشارة المناسب لك",
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 22),
        Text(
          tr("Available Dates", "التواريخ المتاحة"),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
          children: availableDates.map((date) {
            final selected = selectedDate == date;

            return ChoiceChip(
              label: Text(translateDate(date)),
              selected: selected,
              onSelected: (_) => setState(() {
                selectedDate = date;
                selectedTime = null;
              }),
              selectedColor: const Color(0xFF0F8B8D).withOpacity(0.18),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF0F8B8D)
                    : const Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment:
              isArabic ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              tr("Available Times", "الأوقات المتاحة"),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (loadingSlots) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0F8B8D),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
          children: availableTimes.map((time) {
            final selected = selectedTime == time;

            final isPast = selectedDate != null &&
                _parseDateTime(selectedDate!, time).isBefore(DateTime.now());

            final isBooked = _isSlotBooked(time);
            final disabled = isPast || isBooked;

            return GestureDetector(
              onTap: disabled ? null : () => setState(() => selectedTime = time),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isBooked
                      ? Colors.red.shade50
                      : selected
                          ? const Color(0xFF0F8B8D).withOpacity(0.18)
                          : isPast
                              ? const Color(0xFFF3F4F6)
                              : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBooked
                        ? Colors.red.shade200
                        : selected
                            ? const Color(0xFF0F8B8D)
                            : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      translateTime(time),
                      style: TextStyle(
                        color: isBooked
                            ? Colors.red.shade300
                            : isPast
                                ? const Color(0xFF9CA3AF)
                                : selected
                                    ? const Color(0xFF0F8B8D)
                                    : const Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                        decoration:
                            isBooked || isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isBooked)
                      Text(
                        tr("Booked", "محجوز"),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade300,
                        ),
                      ),
                    if (isPast && !isBooked)
                      Text(
                        tr("Passed", "منتهي"),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
          children: [
            _legendItem(
              Colors.red.shade200,
              tr("Already booked", "محجوز مسبقاً"),
            ),
            _legendItem(
              Colors.grey.shade300,
              tr("Time passed", "انتهى الوقت"),
            ),
            _legendItem(
              const Color(0xFF0F8B8D),
              tr("Your selection", "اختيارك"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: Directionality.of(context),
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr("Consultation Summary", "ملخص الاستشارة"),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            "Add optional notes for the doctor",
            "أضف ملاحظات اختيارية للطبيب",
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: notesController,
            maxLines: 4,
            textDirection: Directionality.of(context),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            decoration: InputDecoration(
              hintText: tr("General consultation", "استشارة عامة"),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment:
                isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                tr("Consultation Details", "تفاصيل الاستشارة"),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F8B8D),
                ),
              ),
              const SizedBox(height: 14),
              _summaryItem(
                Icons.chat_bubble_outline,
                translateConsultationType(selectedType ?? ""),
              ),
              _summaryItem(
                Icons.person_outline,
                translateDoctorName(selectedDoctor ?? ""),
              ),
              _summaryItem(
                Icons.medical_services_outlined,
                translateDepartment(selectedDoctorDepartment ?? ""),
              ),
              _summaryItem(
                Icons.badge_outlined,
                translateDoctorSpecialty(selectedDoctorSpecialty ?? ""),
              ),
              _summaryItem(
                Icons.calendar_today_outlined,
                translateDate(selectedDate ?? ""),
              ),
              _summaryItem(
                Icons.access_time_outlined,
                translateTime(selectedTime ?? ""),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF0F8B8D) : const Color(0xFFE5E7EB),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          textDirection: Directionality.of(context),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F8B8D).withOpacity(0.12)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: selected
                    ? const Color(0xFF0F8B8D)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF0F8B8D)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        textDirection: Directionality.of(context),
        children: [
          Icon(icon, color: const Color(0xFF0F8B8D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final bool isLastStep = currentStep == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        textDirection: Directionality.of(context),
        children: [
          Container(
            margin: EdgeInsets.only(
              right: isArabic ? 0 : 12,
              left: isArabic ? 12 : 0,
            ),
            child: OutlinedButton(
              onPressed: previousStep,
              style: OutlinedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Icon(
                isArabic ? Icons.arrow_forward : Icons.arrow_back,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving
                  ? null
                  : isLastStep
                      ? _confirmConsultation
                      : nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F8B8D),
                disabledBackgroundColor: const Color(0xFF0F8B8D),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isLastStep
                          ? tr("Confirm Booking", "تأكيد الحجز")
                          : tr("Next", "التالي"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}