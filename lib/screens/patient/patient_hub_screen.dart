import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'arrival_checkin_screen.dart';
import 'symptom_collector_screen.dart';

class PatientHubScreen extends StatefulWidget {
  const PatientHubScreen({super.key});

  @override
  State<PatientHubScreen> createState() => _PatientHubScreenState();
}

class _PatientHubScreenState extends State<PatientHubScreen> {
  String patientName = "";

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  void _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      patientName = prefs.getString("patient_name") ?? "Patient";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, $patientName')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArrivalCheckinScreen())),
              child: const Text('Arrival Check-In'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomCollectorScreen())),
              child: const Text('Report Symptoms'),
            ),
          ],
        ),
      ),
    );
  }
}
