import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  int currentStep = 0;
  bool isSaving = false;

  final TextEditingController reasonController = TextEditingController();

  String? selectedHospital = "NMC Speciality Hospital";
  String? selectedDepartment;
  String? selectedDoctor;
  String? selectedDoctorUid;
  String? selectedDoctorSpecialty;
  String? selectedDate;
  String? selectedTime;

  final Map<String, List<String>> hospitals = {
    "NMC Speciality Hospital": [
      "Emergency Medicine",
      "Cardiology",
      "Dermatology",
      "ENT",
      "Internal Medicine",
      "Ophthalmology",
      "Gastroenterology",
      "Neuroscience",
      "Paediatrics",
      "Pulmonology",
      "Dentistry",
      "Family Medicine",
      "Orthopaedics",
    ],
  };

  late final List<String> availableDates = List.generate(
    5,
    (index) => DateFormat('EEE, MMM d').format(
      DateTime.now().add(Duration(days: index)),
    ),
  );

  final List<String> availableTimes = [
    "09:00 AM",
    "11:00 AM",
    "01:00 PM",
    "04:00 PM",
    "06:00 PM",
  ];

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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

  bool _isSelectedAppointmentInPast() {
    if (selectedDate == null || selectedTime == null) {
      return false;
    }
    return _parseDateTime(selectedDate!, selectedTime!).isBefore(DateTime.now());
  }

  void nextStep() {
    if (currentStep == 0 && selectedDepartment == null) {
      _showSnack("Please select a department.");
      return;
    }

    if (currentStep == 1 && selectedDoctorUid == null) {
      _showSnack("Please select a doctor.");
      return;
    }

    if (currentStep == 2 && (selectedDate == null || selectedTime == null)) {
      _showSnack("Please select date and time.");
      return;
    }

    if (currentStep == 2 && _isSelectedAppointmentInPast()) {
      _showSnack("Selected appointment time has already passed.");
      return;
    }

    if (currentStep < 3) {
      setState(() {
        currentStep++;
      });
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack("No logged in user found.");
      return;
    }

    if (selectedHospital == null ||
        selectedDepartment == null ||
        selectedDoctorUid == null ||
        selectedDate == null ||
        selectedTime == null) {
      _showSnack("Please complete all booking steps.");
      return;
    }

    if (_isSelectedAppointmentInPast()) {
      _showSnack("Selected appointment time has already passed.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final appointmentRef =
          FirebaseFirestore.instance.collection('appointments').doc();

      final reason = reasonController.text.trim();
      final appointmentData = {
        'appointmentId': appointmentRef.id,
        'patientId': user.uid,
        'hospital': selectedHospital,
        'department': selectedDepartment,
        'doctorName': selectedDoctor,
        'doctorUid': selectedDoctorUid,
        'doctorSpecialty': selectedDoctorSpecialty,
        'date': selectedDate,
        'time': selectedTime,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (reason.isNotEmpty) {
        appointmentData['reason'] = reason;
      }

      await appointmentRef.set(appointmentData);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text(
              "Appointment Booked",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Your appointment with $selectedDoctor at $selectedHospital - "
              "$selectedDepartment on $selectedDate at $selectedTime has been confirmed.",
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
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showSnack("Booking failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
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
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedHospital ?? "Book Appointment",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Book Appointment",
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            width: 34,
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
        return _buildDepartmentStep();
      case 1:
        return _buildDoctorStep();
      case 2:
        return _buildDateTimeStep();
      case 3:
        return _buildReasonSummaryStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDepartmentStep() {
    final departments = hospitals[selectedHospital] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Department",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Choose a department in ${selectedHospital ?? ''}",
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 22),
        ...departments.map(
          (dept) => _selectCard(
            title: dept,
            subtitle: "Available department",
            selected: selectedDepartment == dept,
            icon: Icons.medical_services_outlined,
            onTap: () {
              setState(() {
                selectedDepartment = dept;
                selectedDoctor = null;
                selectedDoctorUid = null;
                selectedDoctorSpecialty = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorStep() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: selectedDepartment)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading doctors: ${snapshot.error}",
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

          if (data['role'] == 'doctor') {
            final doctorUid = (data['uid'] ?? doc.id).toString();

            if (doctorUid.isNotEmpty) {
              uniqueDoctors[doctorUid] = doc;
            }
          }
        }

        final doctors = uniqueDoctors.values.toList();

        if (doctors.isEmpty) {
          return Center(
            child: Text(
              "No doctors found for $selectedDepartment.",
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Doctor",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Available doctors in ${selectedDepartment ?? ''}",
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 22),
            ...doctors.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final doctorName = data['name'] ?? 'Doctor';
              final specialty = data['specialty'] ?? '';
              final doctorUid = (data['uid'] ?? doc.id).toString();

              return _selectCard(
                title: doctorName,
                subtitle: specialty,
                selected: selectedDoctorUid == doctorUid,
                icon: Icons.person_outline,
                onTap: () {
                  setState(() {
                    selectedDoctor = doctorName;
                    selectedDoctorUid = doctorUid;
                    selectedDoctorSpecialty = specialty;
                  });
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Date & Time",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Choose your preferred appointment slot",
          style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 22),
        const Text(
          "Available Dates",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: availableDates.map((date) {
            final selected = selectedDate == date;
            return ChoiceChip(
              label: Text(date),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedDate = date;
                });
              },
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
        const Text(
          "Available Times",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: availableTimes.map((time) {
            final selected = selectedTime == time;
            final dateTime = selectedDate != null
                ? _parseDateTime(selectedDate!, time)
                : null;
            final disabled = dateTime != null && dateTime.isBefore(DateTime.now());
            return ChoiceChip(
              label: Text(time),
              selected: selected,
              onSelected: disabled
                  ? null
                  : (_) {
                      setState(() {
                        selectedTime = time;
                      });
                    },
              selectedColor: const Color(0xFF0F8B8D).withOpacity(0.18),
              backgroundColor:
                  disabled ? const Color(0xFFF3F4F6) : Colors.white,
              labelStyle: TextStyle(
                color: disabled
                    ? const Color(0xFF9CA3AF)
                    : selected
                        ? const Color(0xFF0F8B8D)
                        : const Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReasonSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reason for Visit",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Optional - helps the doctor prepare",
          style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Regular check up",
              contentPadding: EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Appointment Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F8B8D),
                ),
              ),
              const SizedBox(height: 14),
              _summaryItem(Icons.local_hospital, selectedHospital ?? ""),
              _summaryItem(
                Icons.medical_services_outlined,
                selectedDepartment ?? "",
              ),
              _summaryItem(Icons.person_outline, selectedDoctor ?? ""),
              _summaryItem(Icons.badge_outlined, selectedDoctorSpecialty ?? ""),
              _summaryItem(Icons.calendar_today_outlined, selectedDate ?? ""),
              _summaryItem(Icons.access_time_outlined, selectedTime ?? ""),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectCard({
    required String title,
    required String subtitle,
    required bool selected,
    required IconData icon,
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
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F8B8D).withOpacity(0.12)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF0F8B8D)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0F8B8D),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F8B8D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
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
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed: previousStep,
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving
                  ? null
                  : isLastStep
                      ? _confirmBooking
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
                      isLastStep ? "Confirm Booking" : "Next",
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