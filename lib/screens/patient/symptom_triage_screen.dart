import 'package:flutter/material.dart';

class SymptomTriageScreen extends StatefulWidget {
  const SymptomTriageScreen({super.key});

  @override
  State<SymptomTriageScreen> createState() => _SymptomTriageScreenState();
}

class _SymptomTriageScreenState extends State<SymptomTriageScreen> {
  final TextEditingController symptomController = TextEditingController();

  // MCQ selections
  bool cbChestPain = false;
  bool cbShortnessBreath = false;
  bool cbSevereBleeding = false;
  bool cbLossConsciousness = false;
  bool cbHighFever = false;
  bool cbFracture = false;
  bool cbPersistentVomiting = false;

  // Result state
  String _urgencyLevel = "";
  String _recommendation = "";
  Color _resultColor = Colors.transparent;
  Color _resultBgColor = Colors.transparent;
  bool _showResult = false;

  final List<String> emergencyKeywords = ["unconscious", "stroke", "paralysis", "anaphylaxis", "severe burn"];
  final List<String> urgentKeywords = ["abdominal pain", "deep cut", "dizziness", "moderate pain", "fever over 39", "severe headache"];

  bool _containsKeyword(String text, List<String> keywords) {
    text = text.toLowerCase();
    for (String keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  void _collectAndSortSymptoms() {
    bool hasMcqEmergency = cbChestPain || cbShortnessBreath || cbSevereBleeding || cbLossConsciousness;
    bool hasMcqUrgent = cbHighFever || cbFracture || cbPersistentVomiting;
    String rawSymptoms = symptomController.text.trim();

    if (!hasMcqEmergency && !hasMcqUrgent && rawSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or enter symptoms to proceed.")),
      );
      return;
    }

    String urgency;
    String rec;
    Color txtColor;
    Color bgColor;

    if (hasMcqEmergency || _containsKeyword(rawSymptoms, emergencyKeywords)) {
      urgency = "EMERGENCY (Immediate Care Required)";
      txtColor = Colors.red.shade900;
      bgColor = Colors.red.shade100;
      rec = "The symptoms you described could be serious. Please call for an ambulance or go to the nearest Emergency Department without delay.";
    } else if (hasMcqUrgent || _containsKeyword(rawSymptoms, urgentKeywords)) {
      urgency = "URGENT (Prompt Evaluation Needed)";
      txtColor = Colors.orange.shade900;
      bgColor = Colors.orange.shade100;
      rec = "Your symptoms suggest you need prompt medical attention. Please consider visiting an urgent care clinic or contacting your doctor today.";
    } else {
      urgency = "NORMAL (Non-Urgent)";
      txtColor = Colors.green.shade900;
      bgColor = Colors.green.shade100;
      rec = "Your symptoms appear to be non-urgent. We recommend monitoring your condition and booking an appointment with your doctor if they persist or worsen.";
    }

    setState(() {
      _urgencyLevel = urgency;
      _recommendation = rec;
      _resultColor = txtColor;
      _resultBgColor = bgColor;
      _showResult = true;
    });

    // Close keyboard after submitting
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Triage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Select any severe symptoms:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text("Chest Pain", style: TextStyle(color: Colors.red)),
                    value: cbChestPain,
                    onChanged: (val) => setState(() => cbChestPain = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Shortness of Breath", style: TextStyle(color: Colors.red)),
                    value: cbShortnessBreath,
                    onChanged: (val) => setState(() => cbShortnessBreath = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Severe Bleeding", style: TextStyle(color: Colors.red)),
                    value: cbSevereBleeding,
                    onChanged: (val) => setState(() => cbSevereBleeding = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Loss of Consciousness", style: TextStyle(color: Colors.red)),
                    value: cbLossConsciousness,
                    onChanged: (val) => setState(() => cbLossConsciousness = val!),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text("High Fever"),
                    value: cbHighFever,
                    onChanged: (val) => setState(() => cbHighFever = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Suspected Fracture"),
                    value: cbFracture,
                    onChanged: (val) => setState(() => cbFracture = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Persistent Vomiting"),
                    value: cbPersistentVomiting,
                    onChanged: (val) => setState(() => cbPersistentVomiting = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Describe other symptoms:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: symptomController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "e.g., headache, mild stomach pain",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _collectAndSortSymptoms,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("Evaluate Triage Urgency"),
            ),
            const SizedBox(height: 24),
            if (_showResult)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _resultBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _resultColor.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Urgency Level: $_urgencyLevel",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _resultColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Next Steps: $_recommendation",
                      style: TextStyle(
                        fontSize: 16,
                        color: _resultColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
