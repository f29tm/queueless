import 'package:flutter/material.dart';
import 'staff_dashboard_screen.dart';

class StaffHubScreen extends StatelessWidget {
  const StaffHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Hub')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffDashboardScreen())),
          child: const Text('View Dashboard'),
        ),
      ),
    );
  }
}
