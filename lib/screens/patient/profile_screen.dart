import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    final String displayName = auth.userName ?? "User";
    final String displayEmail = auth.currentUser?.email ?? "No email";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ✅ PAGE TITLE
              const Text(
                "Profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ✅ MAIN PROFILE CARD (NOW DYNAMIC)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.teal,
                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                    ),

                    const SizedBox(height: 12),

                    // ✅ DYNAMIC NAME FROM FIRESTORE
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // ✅ DYNAMIC EMAIL FROM AUTH
                    Text(
                      displayEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ COUNTERS ROW (placeholder)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCounter("0", "Visits"),
                        _buildCounter("0", "Appointments"),
                        _buildCounter("0", "Consultations"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ✅ SETTINGS TITLE
              const Text(
                "SETTINGS",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 12),

              // ✅ SETTINGS LIST
              _buildSettingsItem(
                icon: Icons.notifications_none,
                label: "Notifications",
                value: "Enabled",
              ),
              _buildSettingsItem(
                icon: Icons.language,
                label: "Language",
                value: "English",
              ),
              _buildSettingsItem(
                icon: Icons.lock_outline,
                label: "Privacy",
              ),
              _buildSettingsItem(
                icon: Icons.help_outline,
                label: "Help & Support",
              ),

              const SizedBox(height: 30),

              // ✅ SIGN OUT BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ COUNTER WIDGET
Widget _buildCounter(String number, String label) {
  return Column(
    children: [
      Text(
        number,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
        ),
      ),
    ],
  );
}

/// ✅ SETTINGS ITEM
Widget _buildSettingsItem({
  required IconData icon,
  required String label,
  String? value,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 5,
          offset: const Offset(0, 3),
        )
      ],
    ),

    child: Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 14),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),

        if (value != null)
          Text(
            value!,
            style: const TextStyle(color: Colors.grey),
          ),

        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ],
    ),
  );
}