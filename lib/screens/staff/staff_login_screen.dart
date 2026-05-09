
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController staffIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ HEADER
            Container(
              width: double.infinity,
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF009688), Color(0xFF00796B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      "assets/images/logo.png",
                      width: 70,
                      height: 70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Staff Portal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Authorized staff only",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ✅ FORM AREA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Staff Login",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Use your Staff ID and password",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  _input(staffIdController, "Staff ID", Icons.perm_identity),
                  const SizedBox(height: 16),

                  _passwordField(),
                  const SizedBox(height: 24),

                  Center(
  child: GestureDetector(
    onTap: () {
      _showStaffResetDialog(context);
    },
    child: const Text(
      "Forgot Password?",
      style: TextStyle(
        color: Color(0xFF009688),
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

const SizedBox(height: 12),

                  // ✅ LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final error = await auth.staffSignIn(
                          staffId: staffIdController.text.trim(),
                          password: passwordController.text.trim(),
                        );

                        if (error != null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                        } else {
                          if (!mounted) return;
                          Navigator.pop(context); // AuthGate handles routing
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "← Back to User Login",
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF009688)),
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.lock_outline, color: Color(0xFF009688)),
          labelText: "Password",
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => obscurePassword = !obscurePassword);
            },
          ),
        ),
      ),
    );
  }

  void _showStaffResetDialog(BuildContext context) {
  final staffIdController = TextEditingController();
  final emailController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Reset Staff Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your Staff ID and Email"),
            const SizedBox(height: 10),

            TextField(
              controller: staffIdController,
              decoration: const InputDecoration(
                hintText: "Staff ID",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                hintText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final staffId = staffIdController.text.trim();
              final email = emailController.text.trim();

              if (staffId.isEmpty || email.isEmpty) return;

              final error = await Provider.of<AuthProvider>(
                context,
                listen: false,
              ).staffResetPassword(
                staffId: staffId,
                email: email,
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text("Password reset email sent.")),
                );
              } else {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
            ),
            child: const Text("Send",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}
}