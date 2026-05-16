import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class SymptomResultScreen extends StatelessWidget {
  final List<String> selectedSymptoms;
  final String description;

  const SymptomResultScreen({
    super.key,
    required this.selectedSymptoms,
    required this.description,
  });

  // ✅ Severity classification logic (placeholder for now)
  Map<String, dynamic> _classifySymptoms() {
    final emergencyWords = [
      "chest pain",
      "loss of consciousness",
      "seizure",
      "severe bleeding",
      "difficulty breathing",
      "stroke",
      "paralysis",
      "shortness of breath",
    ];

    final urgentWords = [
      "fever",
      "fracture",
      "vomiting",
      "dizziness",
      "severe headache",
      "abdominal pain",
    ];

    final combinedText =
        (selectedSymptoms.join(" ") + " " + description).toLowerCase();

    bool isEmergency = emergencyWords.any((w) => combinedText.contains(w));
    bool isUrgent = urgentWords.any((w) => combinedText.contains(w));

    if (isEmergency) {
      return {
        "level": "EMERGENCY",
        "color": Colors.red,
        "icon": Icons.error_outline,
        "score": 9.0,
        "message":
            "Your symptoms indicate a potential medical emergency. Please go to the nearest Emergency Department immediately.",
        "department": "Emergency Medicine",
        "wait": "Immediate",
        "steps": [
          "Call an ambulance or go to the nearest emergency department.",
          "Do not drive yourself if feeling faint or severe pain.",
          "Stay with a trusted person until help arrives."
        ]
      };
    } else if (isUrgent) {
      return {
        "level": "MODERATE",
        "color": Colors.orange,
        "icon": Icons.report_gmailerrorred,
        "score": 5.5,
        "message":
            "Your symptoms need prompt evaluation today. Please visit an urgent care clinic or consult a doctor.",
        "department": "Urgent Care",
        "wait": "Short Wait",
        "steps": [
          "Visit an urgent care clinic within the next few hours.",
          "Avoid heavy physical activity until medically evaluated.",
          "Monitor your symptoms for any worsening."
        ]
      };
    } else {
      return {
        "level": "LOW",
        "color": Colors.green,
        "icon": Icons.check_circle_outline,
        "score": 2.0,
        "message":
            "Your symptoms appear to be non‑urgent. Monitor at home and book a routine appointment if symptoms persist.",
        "department": "General Medicine",
        "wait": "Standard",
        "steps": [
          "Rest and stay hydrated.",
          "Monitor symptoms for any changes.",
          "Book a routine checkup if symptoms continue."
        ]
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _classifySymptoms();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ✅ SEVERITY BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: result["color"],
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Icon(result["icon"], color: Colors.white, size: 60),
                    const SizedBox(height: 12),
                    Text(
                      result["level"],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result["message"],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        "Severity Score: ${result["score"]}/10",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ✅ INFO CARD (Department, Wait Time)
              _buildInfoCard([
                _infoRow(Icons.local_hospital, "Department",
                    result["department"]),
                _infoRow(Icons.timer_outlined, "Estimated Wait",
                    result["wait"]),
              ]),

              const SizedBox(height: 28),

              // ✅ REPORTED SYMPTOMS SECTION
              const Text(
                "Reported Symptoms",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              _symptomList(selectedSymptoms),

              const SizedBox(height: 28),

              // ✅ NEXT STEPS SECTION (LIKE SAMPLE)
              const Text(
                "Next Steps",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              _buildInfoCard([
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: result["color"].withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(result["icon"], color: result["color"]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        result["message"],
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result["steps"]
                      .map<Widget>((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_right,
                                    color: result["color"]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child:
                                      Text(s, style: const TextStyle(fontSize: 15)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                )
              ]),

              const SizedBox(height: 40),

              Center(
  child: ElevatedButton(
    onPressed: () async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No user logged in")),
        );
        return;
      }

      await FirebaseFirestore.instance.collection("triageResults").add({
        "patientId": user.uid,
        "selectedSymptoms": selectedSymptoms,
        "description": description.isEmpty ? "No description" : description,
        "triageLevel": result["level"],
        "severityScore": result["score"],
        "department": result["department"],
        "wait": result["wait"],
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assessment saved successfully")),
        );

        Navigator.pop(context);
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: result["color"],
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
    child: const Text(
      "Save Assessment",
      style: TextStyle(fontSize: 18, color: Colors.white),
    ),
  ),
)
            ],
          ),
        ),
      ),
    );
  }

  // ✅ reusable info card
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.grey.withOpacity(0.12),
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  // ✅ simple row UI
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ✅ list of reported symptoms
  Widget _symptomList(List<String> symptoms) {
    return Column(
      children: symptoms.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.grey.withOpacity(0.1),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.brightness_1, size: 10, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(child: Text(s, style: const TextStyle(fontSize: 15))),
            ],
          ),
        );
      }).toList(),
    );
  }
}