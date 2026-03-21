import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_hub_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isEmailMode = true;
  bool isLoading = false;
  String? errorMessage;

  void setEmailMode() {
    setState(() {
      isEmailMode = true;
      userController.clear();
      passwordController.clear();
      errorMessage = null;
    });
  }

  void setStaffIdMode() {
    setState(() {
      isEmailMode = false;
      userController.clear();
      passwordController.clear();
      errorMessage = null;
    });
  }

  void validateLogin() async {
    final userInput = userController.text.trim();
    final password = passwordController.text.trim();

    if (userInput.isEmpty || password.isEmpty) {
      setState(() => errorMessage = "Please fill all fields");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      // In a real app we would use FirebaseAuth for staff too. 
      // But preserving the Android Studio logic where "staff" is a custom collection 
      // validated directly by querying the Firestore database for mock testing.
      final querySnapshot = await db
          .collection('staff')
          .where(isEmailMode ? 'email' : 'staffId', isEqualTo: userInput)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => errorMessage = "⚠ You are not authorized as hospital staff.");
        setState(() => isLoading = false);
        return;
      }

      final doc = querySnapshot.docs.first;
      final storedPassword = doc.data()['password'] as String?;

      if (password != storedPassword) {
        setState(() => errorMessage = "Incorrect password");
        setState(() => isLoading = false);
        return;
      }

      // Password correct -> Proceed to Staff Hub 
      // (Bypassing OTP for simplicity in this port unless requested)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StaffHubScreen()),
      );

    } catch (e) {
      setState(() => errorMessage = "Error connecting to Firestore: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.local_hospital, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Authorized Personnel Only',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: setEmailMode,
                  child: Text(
                    'Use Email',
                    style: TextStyle(
                      color: isEmailMode ? Colors.teal : Colors.grey,
                      fontWeight: isEmailMode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: setStaffIdMode,
                  child: Text(
                    'Use Staff ID',
                    style: TextStyle(
                      color: !isEmailMode ? Colors.teal : Colors.grey,
                      fontWeight: !isEmailMode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: userController,
              keyboardType: isEmailMode
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: isEmailMode ? 'Email Address' : 'Staff ID (e.g. ST12345)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(isEmailMode ? Icons.email : Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : validateLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login As Staff', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
