import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ArrivalCheckInScreen extends StatefulWidget {
  const ArrivalCheckInScreen({super.key});

  @override
  State<ArrivalCheckInScreen> createState() => _ArrivalCheckInScreenState();
}

class _ArrivalCheckInScreenState extends State<ArrivalCheckInScreen> {
  bool isLoading = false;

  int _priorityNumber(String triageLevel) {
    final level = triageLevel.toUpperCase();

    if (level.contains("EMERGENCY") || level.contains("HIGH")) return 1;
    if (level.contains("MODERATE") || level.contains("MEDIUM") || level.contains("URGENT")) return 2;
    return 3;
  }

  String _normalizeTriageLevel(String triageLevel) {
    final level = triageLevel.toUpperCase();

    if (level.contains("EMERGENCY") || level.contains("HIGH")) {
      return "EMERGENCY";
    }

    if (level.contains("MODERATE") || level.contains("MEDIUM") || level.contains("URGENT")) {
      return "MODERATE";
    }

    return "LOW";
  }

  Future<void> _checkInPatient() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No patient logged in")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final patientDoc = await firestore.collection("users").doc(user.uid).get();

      final patientData = patientDoc.data() ?? {};
      final patientName =
          patientData["name"] ?? patientData["fullName"] ?? "Unknown Patient";

      final triageQuery = await firestore
          .collection("triageResults")
          .where("patientId", isEqualTo: user.uid)
          .orderBy("createdAt", descending: true)
          .limit(1)
          .get();

      if (triageQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please report symptoms before checking in."),
          ),
        );

        setState(() {
          isLoading = false;
        });

        return;
      }

      final triageDoc = triageQuery.docs.first;
      final triageData = triageDoc.data();

      final rawTriageLevel =
          triageData["triageLevel"] ??
          triageData["level"] ??
          triageData["urgencyLevel"] ??
          triageData["severity"] ??
          "LOW";

      final triageLevel = _normalizeTriageLevel(rawTriageLevel.toString());

      final symptoms =
          triageData["selectedSymptoms"] ??
          triageData["symptoms"] ??
          [];

      final description =
          triageData["description"] ??
          triageData["notes"] ??
          "No description";

      final queueRef = firestore.collection("queue").doc();
      final checkInRef = firestore.collection("checkIns").doc();

      final batch = firestore.batch();

      batch.set(queueRef, {
        "queueId": queueRef.id,
        "patientId": user.uid,
        "patientName": patientName,
        "triageResultId": triageDoc.id,
        "symptoms": symptoms,
        "description": description,
        "triageLevel": triageLevel,
        "priorityNumber": _priorityNumber(triageLevel),
        "queueType": "nurse",
        "status": "waiting_nurse",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      batch.set(checkInRef, {
        "checkInId": checkInRef.id,
        "patientId": user.uid,
        "triageResultId": triageDoc.id,
        "queueId": queueRef.id,
        "arrivalConfirmed": true,
        "status": "checked_in",
        "etaMinutes": 0,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in complete. You are added to the nurse queue."),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Check-in failed: $e")),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "I Have Arrived",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                "Your next appointment:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "NMC Hospital",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Today | Nurse triage check-in",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              const Text(
                "Already at the hospital? Check in here to enter the nurse queue.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                      width: 4,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.blueAccent,
                      size: 40,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _checkInPatient,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.pan_tool, size: 22),
                  label: Text(
                    isLoading ? "Checking in..." : "I Have Arrived",
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  "Tap to manually check in at the hospital",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "OR",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 26),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.blueAccent),
                        SizedBox(width: 12),
                        Text(
                          "Auto-Detect Location",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Enable GPS to automatically detect when you're near the hospital for instant check-in.",
                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Location permission required."),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.location_searching,
                          color: Colors.blueAccent,
                        ),
                        label: const Text(
                          "Enable Location",
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.blueAccent.withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "After check-in, you will be added to the nurse queue for triage validation.",
                  style: TextStyle(
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}