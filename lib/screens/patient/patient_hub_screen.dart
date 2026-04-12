
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'arrival_checkin_screen.dart';
import 'symptom_assessment_screen.dart';
import 'medication_tracker_screen.dart';
import 'profile_screen.dart';

class PatientHubScreen extends StatefulWidget {
  const PatientHubScreen({super.key});

  @override
  State<PatientHubScreen> createState() => _PatientHubScreenState();
}

class _PatientHubScreenState extends State<PatientHubScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context); // ✅ REQUIRED

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHome(context, authProvider),
            _buildChatbotPlaceholder(),
            _buildRecordsPlaceholder(),
            const ProfileScreen(),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: "Chatbot",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: "Records",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  // ✅ CHATBOT PLACEHOLDER
  Widget _buildChatbotPlaceholder() {
    return const Center(
      child: Text(
        "Chatbot coming soon",
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // ✅ RECORDS PLACEHOLDER
  Widget _buildRecordsPlaceholder() {
    return const Center(
      child: Text(
        "Records coming soon",
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  // ✅ HOME CONTENT (with dynamic name)
  Widget _buildHome(BuildContext context, AuthProvider authProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ✅ HEADER (NOW DYNAMIC)
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome back,", style: TextStyle(color: Colors.grey)),

                    // ✅ THIS IS THE FIX — SHOW NAME FROM FIRESTORE
                    Text(
                      authProvider.userName ?? "User",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          _actionRow(
            _quickActionCard(
              icon: Icons.medical_services_outlined,
              iconColor: Colors.teal,
              title: "Report Symptoms",
              subtitle: "Check from home",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SymptomAssessmentScreen()),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.location_on_outlined,
              iconColor: Colors.blue,
              title: "I Have Arrived",
              subtitle: "Skip the queue",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArrivalCheckInScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          _actionRow(
            _quickActionCard(
              icon: Icons.event_available,
              iconColor: Colors.orange,
              title: "Book Appointment",
              subtitle: "Schedule a visit",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Booking coming soon")),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.video_call_outlined,
              iconColor: Colors.indigo,
              title: "Consult Online",
              subtitle: "Talk to a doctor",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Online consultation coming soon")),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          _actionRow(
            _quickActionCard(
              icon: Icons.medication_outlined,
              iconColor: Colors.purple,
              title: "Medication Tracker",
              subtitle: "View prescriptions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.payment_outlined,
              iconColor: Colors.green,
              title: "Payment Portal",
              subtitle: "View & pay bills",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Payment portal coming soon")),
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            "How It Works",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          _howItWorksItem("1", "Report Symptoms", "Describe how you're feeling", Icons.edit_note),
          _howItWorksItem("2", "Get Assessed", "Severity assessment", Icons.analytics_outlined),
          _howItWorksItem("3", "Arrive & Check In", "Skip the queue", Icons.location_on_outlined),
          _howItWorksItem("4", "Follow Your Path", "Step‑by‑step care", Icons.timeline_outlined),
        ],
      ),
    );
  }

  Widget _actionRow(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksItem(String number, String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal.withOpacity(0.15),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Icon(icon, color: Colors.teal),
        ],
      ),
    );
  }
}
