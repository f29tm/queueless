import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'symptom_result_screen.dart';

class SymptomAssessmentScreen extends StatefulWidget {
  const SymptomAssessmentScreen({super.key});

  @override
  State<SymptomAssessmentScreen> createState() =>
      _SymptomAssessmentScreenState();
}

class _SymptomAssessmentScreenState extends State<SymptomAssessmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final Set<String> selectedSymptoms = {};
  final TextEditingController descriptionController = TextEditingController();

  bool isSaving = false;

  final Map<String, List<String>> symptomCategories = {
    "Chest & Heart": [
      "Chest pain",
      "Chest tightness",
      "Shortness of breath",
      "Heart palpitations",
      "Radiating jaw pain"
    ],
    "Head & Neurological": [
      "Headache",
      "Seizures",
      "Dizziness",
      "Vision changes",
      "Confusion",
      "Weakness",
      "Numbness"
    ],
    "Breathing & Respiratory": [
      "Wheezing",
      "Coughing blood",
      "Persistent cough",
      "Sore throat",
      "Trouble breathing"
    ],
    "Abdomen & Digestive": [
      "Abdominal pain",
      "Vomiting",
      "Persistent vomiting",
      "Diarrhea",
      "Blood in stool",
      "Bloating"
    ],
    "General Symptoms": [
      "Fever",
      "Fatigue",
      "Body aches",
      "Weakness",
      "Weight loss"
    ],
    "Muscles & Joints": [
      "Fracture",
      "Joint swelling",
      "Muscle spasms",
      "Back pain"
    ],
    "Mental Health": [
      "Anxiety",
      "Depressed mood",
      "Confusion",
      "Memory issues"
    ],
  };

  final Map<String, IconData> categoryIcons = {
    "Chest & Heart": Icons.favorite_border,
    "Head & Neurological": Icons.psychology_outlined,
    "Breathing & Respiratory": Icons.air,
    "Abdomen & Digestive": Icons.restaurant_menu,
    "General Symptoms": Icons.medical_services_outlined,
    "Muscles & Joints": Icons.accessibility_new,
    "Mental Health": Icons.self_improvement,
  };

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void toggleSymptom(String symptom) {
    setState(() {
      if (selectedSymptoms.contains(symptom)) {
        selectedSymptoms.remove(symptom);
      } else {
        selectedSymptoms.add(symptom);
      }
    });
  }

  Map<String, String> _generateSimpleTriageResult() {
    final selected = selectedSymptoms.map((e) => e.toLowerCase()).toList();
    final description = descriptionController.text.trim().toLowerCase();

    String urgencyLevel = "normal";
    String priorityColor = "green";
    String aiReason = "Symptoms appear non-urgent based on current rules.";
    String recommendedNextStep =
        "Monitor symptoms and book a regular consultation if needed.";

    final emergencyKeywords = [
      "chest pain",
      "shortness of breath",
      "trouble breathing",
      "radiating jaw pain",
      "seizures",
      "confusion",
      "weakness",
      "numbness",
      "coughing blood",
      "blood in stool",
      "persistent vomiting",
    ];

    final urgentKeywords = [
      "dizziness",
      "fever",
      "abdominal pain",
      "vomiting",
      "persistent cough",
      "vision changes",
      "heart palpitations",
      "chest tightness",
    ];

    final bool isEmergency =
        selected.any((s) => emergencyKeywords.contains(s)) ||
            emergencyKeywords.any((k) => description.contains(k));

    final bool isUrgent = selected.any((s) => urgentKeywords.contains(s)) ||
        urgentKeywords.any((k) => description.contains(k));

    if (isEmergency) {
      urgencyLevel = "emergency";
      priorityColor = "red";
      aiReason =
          "Reported symptoms may indicate a serious condition requiring immediate attention.";
      recommendedNextStep =
          "Proceed immediately to the emergency triage desk.";
    } else if (isUrgent) {
      urgencyLevel = "urgent";
      priorityColor = "orange";
      aiReason = "Reported symptoms may require prompt medical evaluation.";
      recommendedNextStep = "Proceed to urgent triage desk for assessment.";
    }

    return {
      'urgencyLevel': urgencyLevel,
      'priorityColor': priorityColor,
      'aiReason': aiReason,
      'recommendedNextStep': recommendedNextStep,
    };
  }

  Future<void> _saveAssessmentFlowToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No logged-in user found.");
    }

    final firestore = FirebaseFirestore.instance;
    final uid = user.uid;

    final triageData = _generateSimpleTriageResult();

    // 1) Create check-in
    final checkInRef = firestore.collection('checkIns').doc();

    await checkInRef.set({
      'checkInId': checkInRef.id,
      'patientId': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'queueId': '',
      'etaMinutes': 0,
      'arrivalConfirmed': false,
      'triageResultId': '',
    });

    // 2) Create symptoms
    final symptomRef = firestore.collection('symptoms').doc();

    await symptomRef.set({
      'symptomId': symptomRef.id,
      'checkInId': checkInRef.id,
      'patientId': uid,
      'selectedSymptoms': selectedSymptoms.toList(),
      'description': descriptionController.text.trim(),
      'language': 'en',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3) Create triage result
    final triageRef = firestore.collection('triageResults').doc();

    await triageRef.set({
      'triageResultId': triageRef.id,
      'checkInId': checkInRef.id,
      'patientId': uid,
      'urgencyLevel': triageData['urgencyLevel'],
      'priorityColor': triageData['priorityColor'],
      'aiReason': triageData['aiReason'],
      'recommendedNextStep': triageData['recommendedNextStep'],
      'reviewedByStaff': false,
      'overriddenBy': '',
      'finalUrgency': triageData['urgencyLevel'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4) Update check-in with triage result ID
    await checkInRef.update({
      'triageResultId': triageRef.id,
    });

    debugPrint("✅ Full assessment flow saved");
    debugPrint("👤 UID: $uid");
    debugPrint("🩺 CheckIn ID: ${checkInRef.id}");
    debugPrint("📝 Symptom ID: ${symptomRef.id}");
    debugPrint("🚦 TriageResult ID: ${triageRef.id}");
  }

  Future<void> _handleGetAssessment() async {
    if (selectedSymptoms.isEmpty &&
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select or describe at least one symptom."),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _saveAssessmentFlowToFirestore();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Assessment saved successfully")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SymptomResultScreen(
            selectedSymptoms: selectedSymptoms.toList(),
            description: descriptionController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ERROR: $e")),
      );

      debugPrint("🔥 Firestore ERROR: $e");
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.2,
        centerTitle: true,
        title: const Text(
          "Symptom Assessment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: Colors.teal,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Select"),
            Tab(text: "Describe"),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: TabBarView(
        controller: tabController,
        children: [
          _buildSelectTab(),
          _buildDescribeTab(),
        ],
      ),
    );
  }

  Widget _buildSelectTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: symptomCategories.entries.map((entry) {
        return _buildCategoryTile(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildDescribeTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: descriptionController,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: "Describe your symptoms",
          alignLabelWithHint: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String category, List<String> symptoms) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withOpacity(0.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: Colors.teal,
        collapsedIconColor: Colors.teal,
        title: Row(
          children: [
            Icon(
              categoryIcons[category] ?? Icons.circle,
              color: Colors.teal,
            ),
            const SizedBox(width: 12),
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: symptoms.map((symptom) {
              final bool isSelected = selectedSymptoms.contains(symptom);

              return GestureDetector(
                onTap: () => toggleSymptom(symptom),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.teal : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    symptom,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.teal.shade900 : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${selectedSymptoms.length} symptoms selected",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          ElevatedButton(
            onPressed: isSaving ? null : _handleGetAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Get Assessment →",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}