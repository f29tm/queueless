import 'package:flutter/material.dart';

class MedicationTrackerScreen extends StatelessWidget {
  const MedicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.2,
        title: const Text(
          "Medication Tracker",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ Section Title
            const Text(
              "Today's Medications",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Medication Card Example 1
            _medicationCard(
              name: "Amoxicillin 500mg",
              dose: "1 capsule • 3 times daily",
              nextDose: "2:00 PM",
              color: Colors.blueAccent,
            ),

            const SizedBox(height: 14),

            // ✅ Medication Card Example 2
            _medicationCard(
              name: "Panadol 500mg",
              dose: "2 tablets • Every 8 hours",
              nextDose: "6:30 PM",
              color: Colors.teal,
            ),

            const SizedBox(height: 30),

            // ✅ All Prescriptions Section
            const Text(
              "All Prescriptions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Prescription Summary Card
            _prescriptionSummaryCard(
              medName: "Amoxicillin 500mg",
              doctor: "Dr. Meriem Bettayeb",
              date: "Jan 12 - Jan 19",
              remaining: "6 doses left",
            ),

            const SizedBox(height: 14),

            _prescriptionSummaryCard(
              medName: "Vitamin D 50,000 IU",
              doctor: "Dr. Sarah Mahmood",
              date: "Ongoing",
              remaining: "Refill in 12 days",
              warn: true,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ Medication Card (for Today)
  Widget _medicationCard({
    required String name,
    required String dose,
    required String nextDose,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication_liquid, color: color),
          ),

          const SizedBox(width: 16),

          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dose,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  "Next dose: $nextDose",
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Checkbox Button
          Container(
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text(
              "Taken",
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  // ✅ Prescription Summary Card
  Widget _prescriptionSummaryCard({
    required String medName,
    required String doctor,
    required String date,
    required String remaining,
    bool warn = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medName,
            style: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text("Prescribed by: $doctor",
              style: const TextStyle(color: Colors.grey)),
          Text("Duration: $date",
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: warn ? Colors.orange.shade100 : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              remaining,
              style: TextStyle(
                color: warn ? Colors.orange.shade800 : Colors.teal.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}