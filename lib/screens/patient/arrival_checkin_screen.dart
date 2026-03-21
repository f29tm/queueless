import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ArrivalCheckInScreen extends StatefulWidget {
  const ArrivalCheckInScreen({super.key});

  @override
  State<ArrivalCheckInScreen> createState() => _ArrivalCheckInScreenState();
}

class _ArrivalCheckInScreenState extends State<ArrivalCheckInScreen> {
  bool _isCheckedIn = false;
  
  static const String mockDoctor = "Dr. Meriem Bettayeb (Cardiology)";
  static const String mockTimeLocation = "Today at 10:30 AM | Clinic 3, 2nd Floor";
  static const int mockQueuePosition = 3;
  static const String mockPathwayGuidance = "Proceed directly to Clinic 3, 2nd Floor.";

  void _handleCheckIn() {
    setState(() {
      _isCheckedIn = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Check-In Signal Sent to Hospital System.")),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return "th";
    switch (n % 10) {
      case 1:  return "st";
      case 2:  return "nd";
      case 3:  return "rd";
      default: return "th";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String firstName = authProvider.user?.email?.split('@').first ?? 'Patient';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $firstName!",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Your Next Appointment",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(mockDoctor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(child: Text(mockTimeLocation, style: TextStyle(fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isCheckedIn ? null : _handleCheckIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCheckedIn ? Colors.grey : Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(_isCheckedIn ? "CHECKED IN" : "I HAVE ARRIVED"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isCheckedIn) _buildQueueStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatusCard() {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text("Check-In Successful", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "You are currently: $mockQueuePosition${_getOrdinal(mockQueuePosition)} in line.",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              "Pathway: $mockPathwayGuidance",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
