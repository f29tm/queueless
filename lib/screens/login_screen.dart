
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'staff/staff_login_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;
  bool _isLoading = false;
  String? _emailFieldError;
  String? _passwordFieldError;

  @override
  void initState() {
    super.initState();
    emailController.addListener(() {
      if (_emailFieldError != null) setState(() => _emailFieldError = null);
    });
    passwordController.addListener(() {
      if (_passwordFieldError != null) setState(() => _passwordFieldError = null);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ HEADER WITH LOGO (same as Register)
            Container(
              height: 260,
              width: double.infinity,
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
                  // ✅ LOGO BOX
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 70,
                      height: 70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "QueueLess",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Skip the wait, not the care",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ✅ White bottom section
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
                    "Welcome back",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Sign in with your email",
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // ✅ Email
                  _inputField(
                    controller: emailController,
                    icon: Icons.email_outlined,
                    hint: "Email Address",
                    error: _emailFieldError,
                  ),

                  const SizedBox(height: 16),

                  // ✅ Password
                  _passwordField(error: _passwordFieldError),

                  const SizedBox(height: 24),

Center(
  child: TextButton(
    onPressed: () => _showResetPasswordDialog(context),
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



                  // ✅ SIGN IN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // Empty-field guards — no API call needed
                              if (passwordController.text.trim().isEmpty) {
                                setState(() => _passwordFieldError =
                                    "Please enter your password.");
                                return;
                              }

                              setState(() => _isLoading = true);
                              try {
                                final error = await auth.signIn(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                );
                                if (!context.mounted) return;
                                if (error != null) {
                                  if (error.contains('user-not-found') ||
                                      error.contains('invalid-credential') ||
                                      error.contains('wrong-password')) {
                                    setState(() {
                                      _emailFieldError = null;
                                      _passwordFieldError =
                                          "Incorrect email or password. Please try again.";
                                    });
                                  } else {
                                    setState(() {
                                      _emailFieldError = null;
                                      _passwordFieldError = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                  return;
                                }
                                setState(() {
                                  _emailFieldError = null;
                                  _passwordFieldError = null;
                                });
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/patient-hub',
                                  (route) => false,
                                );
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
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
                              "Sign In",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ STAFF LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffLoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF009688)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Staff Login",
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ FOOTER: Sign Up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Color(0xFF009688),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Email Input
  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null ? Colors.red.shade50 : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border: error != null ? Border.all(color: Colors.red.shade300) : null,
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF009688)),
              hintText: hint,
              border: InputBorder.none,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ✅ Password Input
  Widget _passwordField({String? error}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null ? Colors.red.shade50 : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border: error != null ? Border.all(color: Colors.red.shade300) : null,
          ),
          child: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.lock_outline, color: Color(0xFF009688)),
              hintText: "Password",
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showResetPasswordDialog(BuildContext context) {
  final TextEditingController resetEmailController = TextEditingController();
  String? emailError;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Reset Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter your email address"),
                const SizedBox(height: 10),
                TextField(
                  controller: resetEmailController,
                  decoration: InputDecoration(
                    hintText: "example@gmail.com",
                    border: const OutlineInputBorder(),
                    errorText: emailError,
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
                  final email = resetEmailController.text.trim();

                  if (email.isEmpty) {
                    setState(() => emailError = 'Please enter your email address');
                    return;
                  }
                  setState(() => emailError = null);

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);

                  try {
                    await authProvider.sendPasswordResetEmail(email);

                    navigator.pop();

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text("Password reset email sent."),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
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
    },
  );
}
  
}