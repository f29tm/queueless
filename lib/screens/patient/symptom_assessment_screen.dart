import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/triage_service.dart';
import 'symptom_result_screen.dart';

const Set<String> _triageRelevantSymptoms = {
  'Chest pain', 'Shortness of breath', 'Trouble breathing',
  'Abdominal pain', 'Headache', 'Seizures', 'Dizziness', 'Fever',
  'Confusion', 'Weakness', 'Vomiting', 'Persistent vomiting',
  'Coughing blood', 'Fracture', 'Back pain',
  'Radiating jaw pain', 'Heart palpitations',
};

class SymptomAssessmentScreen extends StatefulWidget {
  const SymptomAssessmentScreen({super.key});

  @override
  State<SymptomAssessmentScreen> createState() =>
      _SymptomAssessmentScreenState();
}

class _SymptomAssessmentScreenState extends State<SymptomAssessmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Set<String> _selectedSymptoms = {};
  final TextEditingController _descriptionController = TextEditingController();

  double _nrsPain = 0.0;
  int _arrivalMode = 1;
  int _injury = 2;
  int _mental = 1;

  String? _patientName;
  int? _age;
  int? _sex;
  bool _isLoading = false;

  final Map<String, List<String>> _symptomCategories = {
    "Chest & Heart": [
      "Chest pain", "Chest tightness", "Shortness of breath",
      "Heart palpitations", "Radiating jaw pain",
    ],
    "Head & Neurological": [
      "Headache", "Seizures", "Dizziness", "Vision changes",
      "Confusion", "Weakness", "Numbness",
    ],
    "Breathing & Respiratory": [
      "Wheezing", "Coughing blood", "Persistent cough",
      "Sore throat", "Trouble breathing",
    ],
    "Abdomen & Digestive": [
      "Abdominal pain", "Vomiting", "Persistent vomiting",
      "Diarrhea", "Blood in stool", "Bloating",
    ],
    "General Symptoms": [
      "Fever", "Fatigue", "Body aches", "Weakness", "Weight loss",
    ],
    "Muscles & Joints": [
      "Fracture", "Joint swelling", "Muscle spasms", "Back pain",
    ],
    "Mental Health": [
      "Anxiety", "Depressed mood", "Confusion", "Memory issues",
    ],
  };

  final Map<String, IconData> _categoryIcons = {
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
    _tabController = TabController(length: 3, vsync: this);
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _patientName = data['name'] as String?;
          final dob = data['dob'] as String?;
          final gender = data['gender'] as String?;
          if (dob != null) _age = TriageService.ageFromDob(dob);
          if (gender != null) _sex = TriageService.sexFromGender(gender);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Color get _painColor {
    if (_nrsPain <= 3) return Colors.green;
    if (_nrsPain <= 6) return Colors.orange;
    return Colors.red;
  }

  Future<void> _handleGetAssessment() async {
    final description = _descriptionController.text.trim();

    if (_selectedSymptoms.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select or describe at least one symptom.")),
      );
      return;
    }

    if (_age == null || _sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Could not load your profile. Please try again.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String chiefComplaint = _selectedSymptoms.join(', ');
      if (description.isNotEmpty) {
        chiefComplaint += chiefComplaint.isNotEmpty
            ? '. Patient says: $description'
            : description;
      }
      if (chiefComplaint.isEmpty) chiefComplaint = 'general complaint';

      final request = Stage1Request(
        chiefComplaint: chiefComplaint,
        age: _age!,
        sex: _sex!,
        pain: _nrsPain > 0 ? 1 : 2,
        nrsPain: _nrsPain,
        mental: _mental,
        arrivalMode: _arrivalMode,
        injury: _injury,
        patientsPerHour: 8,
      );

      final result = await TriageService.predictStage1(request);

      if (!mounted) return;

      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Could not reach AI model. Check connection and try again.")),
        );
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      final ref =
          await FirebaseFirestore.instance.collection('queue').add({
        'patientId': uid,
        'patientName': _patientName ?? 'Unknown',
        'queueType': 'pre_arrival',
        'status': 'pre_arrival',
        'priorityNumber': result.priorityNumber,
        'triageLevel': result.triageLevel,
        'symptoms': _selectedSymptoms.toList(),
        'description': description,
        'aiPrediction': result.prediction,
        'confidence': result.confidence,
        'deferred': result.deferred,
        'probabilities': result.probabilities,
        'entropy': result.entropy,
        'stage1Inputs': request.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SymptomResultScreen(
            triageResult: result,
            queueDocId: ref.id,
            selectedSymptoms: _selectedSymptoms.toList(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Could not reach AI model. Check connection and try again.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Symptom Assessment",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Symptoms"),
            Tab(text: "Describe"),
            Tab(text: "Details"),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSymptomsTab(),
          _buildDescribeTab(),
          _buildDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildSymptomsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Triage-relevant symptom",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        ..._symptomCategories.entries
            .map((e) => _buildCategoryTile(e.key, e.value)),
      ],
    );
  }

  Widget _buildDescribeTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _descriptionController,
        maxLines: 8,
        onChanged: (_) => setState(() {}),
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

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionLabel("Pain Level (NRS)"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("No pain",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _painColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Pain: ${_nrsPain.toInt()}/10",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  const Text("Worst",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              Slider(
                value: _nrsPain,
                min: 0,
                max: 10,
                divisions: 10,
                activeColor: _painColor,
                onChanged: (v) => setState(() => _nrsPain = v),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _sectionLabel("How will you arrive?"),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _arrivalChip(1, Icons.directions_walk, "Walking"),
            _arrivalChip(2, Icons.emergency, "Ambulance"),
            _arrivalChip(3, Icons.directions_car, "Private car"),
            _arrivalChip(4, Icons.directions_bus, "Public transport"),
            _arrivalChip(5, Icons.local_hospital, "Referral"),
          ],
        ),

        const SizedBox(height: 24),

        _sectionLabel("Is this injury-related?"),
        const SizedBox(height: 10),
        Row(
          children: [
            _injuryChip(1, "Yes"),
            const SizedBox(width: 10),
            _injuryChip(2, "No"),
          ],
        ),

        const SizedBox(height: 24),

        _sectionLabel("Alertness Level (AVPU)"),
        const SizedBox(height: 10),
        _avpuCard(1, "Alert", "Fully awake and aware of surroundings"),
        _avpuCard(2, "Verbal", "Responds to voice but may be confused"),
        _avpuCard(
            3, "Pain response", "Only responds to painful stimulus"),
        _avpuCard(4, "Unresponsive", "No response to voice or pain"),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87),
      );

  Widget _arrivalChip(int value, IconData icon, String label) {
    final bool selected = _arrivalMode == value;
    return GestureDetector(
      onTap: () => setState(() => _arrivalMode = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.teal : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.teal.shade900 : Colors.black87,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _injuryChip(int value, String label) {
    final bool selected = _injury == value;
    return GestureDetector(
      onTap: () => setState(() => _injury = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.teal.shade900 : Colors.black87,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _avpuCard(int value, String title, String description) {
    final bool selected = _mental == value;
    return GestureDetector(
      onTap: () => setState(() => _mental = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? Colors.teal : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? Colors.teal : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.teal.shade900
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
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
            Icon(_categoryIcons[category] ?? Icons.circle,
                color: Colors.teal),
            const SizedBox(width: 12),
            Text(category,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptoms.map((symptom) {
                final bool isSelected =
                    _selectedSymptoms.contains(symptom);
                final bool isRelevant =
                    _triageRelevantSymptoms.contains(symptom);
                return GestureDetector(
                  onTap: () => _toggleSymptom(symptom),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.teal
                            : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRelevant) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          symptom,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.teal.shade900
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Color(0x11000000)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Pain: ${_nrsPain.toInt()}/10 · ${_selectedSymptoms.length} symptoms",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleGetAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "Get AI Assessment →",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
