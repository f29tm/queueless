import 'package:flutter/material.dart';

class PatientQueueEntry {
  final String name;
  final String symptoms;
  final String urgencyLevel;
  final String checkInTime;

  PatientQueueEntry({
    required this.name,
    required this.symptoms,
    required this.urgencyLevel,
    required this.checkInTime,
  });
}

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  List<PatientQueueEntry> patientList = [];

  @override
  void initState() {
    super.initState();
    _loadMockPatientData();
    _sortPatientQueue();
  }

  void _loadMockPatientData() {
    patientList = [
      PatientQueueEntry(
        name: "Khalid Al Marzouqi",
        symptoms: "Severe chest pain (MCQ selected)",
        urgencyLevel: "EMERGENCY",
        checkInTime: "10:01 AM",
      ),
      PatientQueueEntry(
        name: "Fatima Ahmed",
        symptoms: "Broken finger (Typing matched 'broken bone')",
        urgencyLevel: "URGENT",
        checkInTime: "09:55 AM",
      ),
      PatientQueueEntry(
        name: "Yousef Ali",
        symptoms: "Persistent vomiting, high fever (MCQ selected)",
        urgencyLevel: "URGENT",
        checkInTime: "10:15 AM",
      ),
      PatientQueueEntry(
        name: "Aisha Mansour",
        symptoms: "Minor headache, sore throat",
        urgencyLevel: "NORMAL",
        checkInTime: "09:45 AM",
      ),
      PatientQueueEntry(
        name: "Hassan Saeed",
        symptoms: "Follow-up appointment, no new symptoms",
        urgencyLevel: "NORMAL",
        checkInTime: "10:20 AM",
      ),
    ];
  }

  int _getUrgencyRank(String urgency) {
    switch (urgency.toUpperCase()) {
      case "EMERGENCY":
        return 3;
      case "URGENT":
        return 2;
      case "NORMAL":
        return 1;
      default:
        return 0;
    }
  }

  void _sortPatientQueue() {
    patientList.sort((p1, p2) {
      int rank1 = _getUrgencyRank(p1.urgencyLevel);
      int rank2 = _getUrgencyRank(p2.urgencyLevel);

      if (rank1 != rank2) {
        return rank2.compareTo(rank1); // Descending (highest rank first)
      } else {
        return p1.checkInTime.compareTo(p2.checkInTime); // Ascending time
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int total = patientList.length;
    int emergencies = patientList.where((p) => p.urgencyLevel == "EMERGENCY").length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Queue Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            width: double.infinity,
            child: Text(
              "Total Patients Waiting: $total | Emergencies: $emergencies",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: patientList.length,
              itemBuilder: (context, index) {
                final patient = patientList[index];
                return _buildPatientCard(patient);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(PatientQueueEntry patient) {
    Color badgeBgColor;
    Color badgeTextColor = Colors.white;

    switch (patient.urgencyLevel) {
      case "EMERGENCY":
        badgeBgColor = Colors.red;
        break;
      case "URGENT":
        badgeBgColor = Colors.orange;
        break;
      default:
        badgeBgColor = Colors.grey;
        badgeTextColor = Colors.black;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    patient.urgencyLevel,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Symptoms: ${patient.symptoms}",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              "Check-In Time: ${patient.checkInTime}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
