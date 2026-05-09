import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  final TextEditingController notesController = TextEditingController();

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

  final List<String> availableDates = [
    "Thu, Feb 26",
    "Fri, Feb 27",
    "Sat, Feb 28",
    "Sun, Mar 1",
  ];

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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void nextStep() {
    if (currentStep == 0 && selectedType == null) {
      _showSnack("Please select a consultation type.");
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

  Future<void> _confirmConsultation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack("No logged in user found.");
      return;
    }

    if (selectedType == null ||
        selectedDoctorUid == null ||
        selectedDate == null ||
        selectedTime == null) {
      _showSnack("Please complete all consultation steps.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final consultationRef =
          FirebaseFirestore.instance.collection('consultations').doc();

      await consultationRef.set({
        'consultationId': consultationRef.id,
        'patientId': user.uid,
        'consultationType': selectedType,
        'doctorName': selectedDoctor,
        'doctorUid': selectedDoctorUid,
        'doctorDepartment': selectedDoctorDepartment,
        'doctorSpecialty': selectedDoctorSpecialty,
        'date': selectedDate,
        'time': selectedTime,
        'notes': notesController.text.trim().isEmpty
            ? "General consultation"
            : notesController.text.trim(),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

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
              "Consultation Booked",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Your $selectedType with $selectedDoctor on $selectedDate at $selectedTime has been confirmed.",
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
      child: const Center(
        child: Text(
          "Online Consultation",
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Online Consultation",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Connect with a healthcare professional from anywhere",
          style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 22),
        const Text(
          "Consultation Type",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 16),
        ...consultationTypes.map((type) {
          return _selectCard(
            title: type["title"],
            subtitle: type["subtitle"],
            icon: type["icon"],
            selected: selectedType == type["title"],
            onTap: () {
              setState(() {
                selectedType = type["title"];
              });
            },
          );
        }),
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

          final doctorUid = (data['uid'] ?? doc.id).toString();

          if (doctorUid.isNotEmpty) {
            uniqueDoctors[doctorUid] = doc;
          }
        }

        final doctors = uniqueDoctors.values.toList();

        if (doctors.isEmpty) {
          return const Center(
            child: Text(
              "No doctors found.",
              style: TextStyle(fontSize: 16),
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
            const Text(
              "Choose a doctor for your consultation",
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 22),
            ...doctors.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final doctorName = data['name'] ?? 'Doctor';
              final specialty = data['specialty'] ?? '';
              final department = data['department'] ?? '';
              final doctorUid = (data['uid'] ?? doc.id).toString();

              return _selectCard(
                title: doctorName,
                subtitle: "$department • $specialty",
                icon: Icons.person_outline,
                selected: selectedDoctorUid == doctorUid,
                onTap: () {
                  setState(() {
                    selectedDoctor = doctorName;
                    selectedDoctorUid = doctorUid;
                    selectedDoctorDepartment = department;
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
          "Choose your preferred consultation slot",
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
            return ChoiceChip(
              label: Text(time),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedTime = time;
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
      ],
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Consultation Summary",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Add optional notes for the doctor",
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
            controller: notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "General consultation",
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
                "Consultation Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F8B8D),
                ),
              ),
              const SizedBox(height: 14),
              _summaryItem(Icons.chat_bubble_outline, selectedType ?? ""),
              _summaryItem(Icons.person_outline, selectedDoctor ?? ""),
              _summaryItem(
                Icons.medical_services_outlined,
                selectedDoctorDepartment ?? "",
              ),
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
            )
          ],
        ),
        child: Row(
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