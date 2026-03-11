import 'package:flutter/material.dart';
import 'package:queueless/screens/register_screen.dart';
import 'package:queueless/screens/verification_screen.dart';
import 'package:queueless/screens/visitor_home_screen.dart';
import 'package:queueless/screens/staff/staff_login_screen.dart';
import 'package:queueless/screens/reset_password_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/email_sender.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isEmailMode = true;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  void setEmailMode() {
    setState(() {
      isEmailMode = true;
      userController.clear();
      passwordController.clear();
    });
  }

  void setPhoneMode() {
    setState(() {
      isEmailMode = false;
      userController.clear();
      passwordController.clear();
    });
  }

  String maskEmail(String email) {
    if (!email.contains('@')) return email;
    int index = email.indexOf("@");
    if (index <= 2) {
      return "\${email[0]}***\${email.substring(index)}";
    }
    String visible = email.substring(0, 2);
    String domain = email.substring(index);
    return "$visible***$domain";
  }

  void validateLogin() async {
    final userInput = userController.text.trim();
    final password = passwordController.text.trim();

    if (isEmailMode) {
      if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$").hasMatch(userInput)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email address')));
        return;
      }
    } else {
      if (!RegExp(r"^\d{10,15}\$").hasMatch(userInput)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid phone number')));
        return;
      }
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password cannot be empty')));
      return;
    }

    String searchField = isEmailMode ? "email" : "phone";

    try {
      final query = await db.collection("users").where(searchField, isEqualTo: userInput).get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEmailMode ? "No account found with this email" : "No account found with this phone number"))
        );
        return;
      }

      final doc = query.docs.first;
      final savedPassword = doc["password"];
      final role = doc["role"];
      final firstName = doc["firstName"];

      if (password != savedPassword) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect password")));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("patient_name", firstName ?? "");

      String otp = (Random().nextInt(900000) + 100000).toString();
      int expireTime = DateTime.now().millisecondsSinceEpoch + 120000;

      String emailToSend = isEmailMode ? userInput : doc["email"];
      String masked = maskEmail(emailToSend);

      EmailSender.sendEmail(
        toEmail: emailToSend,
        subject: "Your Login Verification Code",
        otp: "Your OTP is: $otp",
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            otp: otp,
            maskedEmail: masked,
            email: emailToSend,
            method: isEmailMode ? "email" : "phone",
            role: role,
            expireTime: expireTime,
            isReset: false,
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: \${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              // Language toggle logic can go here
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Sign In',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: setEmailMode,
                  child: Text(
                    'Use Email',
                    style: TextStyle(color: isEmailMode ? Colors.blue : Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: setPhoneMode,
                  child: Text(
                    'Use Phone',
                    style: TextStyle(color: !isEmailMode ? Colors.blue : Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: userController,
              keyboardType: isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
              decoration: InputDecoration(
                labelText: isEmailMode ? 'Email Address' : 'Phone Number',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: validateLogin,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Login'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
                  child: const Text('Forgot Password?'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Create Account'),
                ),
              ],
            ),
            const Divider(),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorHomeScreen())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
              child: const Text('Continue as Visitor'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffLoginScreen())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
              child: const Text('Staff Login'),
            ),
          ],
        ),
      ),
    );
  }
}
