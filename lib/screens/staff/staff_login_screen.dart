import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'staff_dashboard_screen.dart';
import '../doctor/doctor_dashboard_screen.dart';
import '../nurse/nurse_dashboard_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController staffIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool _isLoading = false;
  String? _staffIdError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    staffIdController.addListener(() {
      if (_staffIdError != null) setState(() => _staffIdError = null);
    });
    passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    staffIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showPatientPortalAlert() {
    setState(() {
      _staffIdError =
          "This portal is for authorized staff only. Please use the patient login.";
      _passwordError = null;
    });
  }

  Future<void> _login() async {
    // Empty field guards
    final idEmpty = staffIdController.text.trim().isEmpty;
    final passEmpty = passwordController.text.trim().isEmpty;
    if (idEmpty || passEmpty) {
      setState(() {
        _staffIdError = idEmpty ? "Please enter your Staff ID." : null;
        _passwordError = passEmpty ? "Please enter your password." : null;
      });
      return;
    }

    // If input looks like an email, it's a patient using the wrong portal
    if (staffIdController.text.trim().contains('@')) {
      _showPatientPortalAlert();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final error = await auth.staffSignIn(
        staffId: staffIdController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      if (error != null) {
        if (error.contains('Staff ID not found')) {
          setState(() {
            _staffIdError = "Staff ID not found. Check your ID and try again.";
            _passwordError = null;
          });
        } else if (error == 'WRONG_PASSWORD') {
          setState(() {
            _staffIdError = null;
            _passwordError = "Incorrect password. Please try again.";
          });
        } else {
          setState(() {
            _staffIdError = null;
            _passwordError = null;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        }
        return;
      }

      final role = auth.userRole?.toLowerCase().trim();

      if (role == "patient") {
        await auth.signOut();
        if (!mounted) return;
        _showPatientPortalAlert();
      } else if (role == "doctor") {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorDashboardScreen(),
          ),
          (route) => false,
        );
      } else if (role == "nurse") {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const NurseDashboardScreen(),
          ),
          (route) => false,
        );
      } else if (role == "staff") {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const StaffDashboardScreen(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid role. Please contact admin."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2446B8), Color(0xFF1C3795)],
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
                      color: const Color(0xFFF2F2F2),
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

                  _input(staffIdController, "Staff ID", Icons.perm_identity,
                      error: _staffIdError),
                  const SizedBox(height: 16),

                  _passwordField(error: _passwordError),
                  const SizedBox(height: 24),

                  Center(
                    child: TextButton(
                      onPressed: () => _showStaffResetDialog(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color(0xFF2446B8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2446B8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Login",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "← Back to User Login",
                        style: TextStyle(
                          color: Color(0xFF2446B8),
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

  Widget _input(TextEditingController c, String label, IconData icon,
      {String? error}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null ? Colors.red.shade50 : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border:
                error != null ? Border.all(color: Colors.red.shade300) : null,
          ),
          child: TextField(
            controller: c,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF2446B8)),
              labelText: label,
              border: InputBorder.none,
            ),
          ),
        ),
        if (error != null) _errorText(error),
      ],
    );
  }

  Widget _passwordField({String? error}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null ? Colors.red.shade50 : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border:
                error != null ? Border.all(color: Colors.red.shade300) : null,
          ),
          child: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.lock_outline, color: Color(0xFF2446B8)),
              labelText: "Password",
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
              ),
            ),
          ),
        ),
        if (error != null) _errorText(error),
      ],
    );
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 13, color: Colors.red),
          const SizedBox(width: 4),
          Flexible(
            child: Text(msg,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showStaffResetDialog(BuildContext context) {
    final resetStaffIdController = TextEditingController();
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
                controller: resetStaffIdController,
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
                final staffId = resetStaffIdController.text.trim();
                final email = emailController.text.trim();

                if (staffId.isEmpty || email.isEmpty) return;

                final error = await Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).staffResetPassword(
                  staffId: staffId,
                  email: email,
                );

                if (!context.mounted) return;

                Navigator.pop(context);

                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password reset email sent."),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
              ),
              child: const Text(
                "Send",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}