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

  // ✅ Store selected symptoms
  final Set<String> selectedSymptoms = {};

  // ✅ Full categories + symptoms
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

  // ✅ Category Icons
  final Map<String, IconData> categoryIcons = {
    "Chest & Heart": Icons.favorite_border,
    "Head & Neurological": Icons.psychology_outlined,
    "Breathing & Respiratory": Icons.air,
    "Abdomen & Digestive": Icons.restaurant_menu,
    "General Symptoms": Icons.medical_services_outlined,
    "Muscles & Joints": Icons.accessibility_new,
    "Mental Health": Icons.self_improvement,
  };

  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    tabController = TabController(length: 2, vsync: this);
    super.initState();
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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

  // ✅ SELECT TAB
  Widget _buildSelectTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: symptomCategories.entries.map((entry) {
        return _buildCategoryTile(entry.key, entry.value);
      }).toList(),
    );
  }

  // ✅ DESCRIBE TAB
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

  // ✅ CATEGORY EXPANSION TILE (with icons + clean chips)
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

        // ✅ Category Title with Icon
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
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.teal
                          : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    symptom,
                    style: TextStyle(
                      color: isSelected ? Colors.teal.shade900 : Colors.black87,
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

  // ✅ Bottom Bar
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SymptomResultScreen(
                    selectedSymptoms: selectedSymptoms.toList(),
                    description: descriptionController.text,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "Get Assessment →",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}