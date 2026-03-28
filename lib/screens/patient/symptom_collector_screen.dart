import 'package:flutter/material.dart';

class SymptomCollectorScreen extends StatefulWidget {
  const SymptomCollectorScreen({super.key});

  @override
  State<SymptomCollectorScreen> createState() => _SymptomCollectorScreenState();
}

class _SymptomCollectorScreenState extends State<SymptomCollectorScreen> {
  final List<String> _symptoms = [
    "Severe Chest Pain",
    "Shortness of Breath / Difficulty Breathing",
    "Uncontrolled / Severe Bleeding",
    "Loss of Consciousness / Fainting",
    "High Fever (above 39°C / 102.2°F)",
    "Suspected Fracture / Dislocation",
    "Persistent Vomiting or Diarrhea",
  ];

  final Map<String, bool> _selectedSymptoms = {};
  final TextEditingController _additionalSymptomsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (var symptom in _symptoms) {
      _selectedSymptoms[symptom] = false;
    }
  }

  void _determineUrgency() {
    // Determine urgency logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Urgency calculation logic not yet implemented')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Symptom Check-In'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Symptom Check-In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Select any symptoms that apply below.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _symptoms.length,
                itemBuilder: (context, index) {
                  final symptom = _symptoms[index];
                  return CheckboxListTile(
                    title: Text(
                      symptom,
                      style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                    ),
                    value: _selectedSymptoms[symptom],
                    onChanged: (bool? value) {
                      setState(() {
                        _selectedSymptoms[symptom] = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    dense: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '2. Describe any other symptoms in detail below.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _additionalSymptomsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Enter additional symptoms here (e.g., 'headache')...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _determineUrgency,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Determine Urgency',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
