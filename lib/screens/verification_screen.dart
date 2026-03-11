import 'package:flutter/material.dart';
import 'package:queueless/screens/patient/patient_hub_screen.dart';
import 'package:queueless/screens/staff/staff_hub_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationScreen extends StatefulWidget {
  final String otp;
  final String maskedEmail;
  final String email;
  final String method;
  final String role;
  final int expireTime;
  final bool isReset;

  const VerificationScreen({
    super.key,
    required this.otp,
    required this.maskedEmail,
    required this.email,
    required this.method,
    required this.role,
    required this.expireTime,
    required this.isReset,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  late String currentOtp;
  late int currentExpireTime;

  @override
  void initState() {
    super.initState();
    currentOtp = widget.otp;
    currentExpireTime = widget.expireTime;
  }

  void verifyOtp() async {
    if (DateTime.now().millisecondsSinceEpoch > currentExpireTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired. Please resend.')),
      );
      return;
    }

    if (otpController.text == currentOtp) {
      try {
        // Mark email as verified in the database
        if (!widget.isReset) {
          final db = FirebaseFirestore.instance;
          await db
              .collection("users")
              .where("email", isEqualTo: widget.email)
              .get()
              .then((query) {
                if (query.docs.isNotEmpty) {
                  query.docs.first.reference.update({"emailVerified": true});
                }
              });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification Successful!')),
        );

        if (widget.isReset) {
          // Go to reset password new screen
        } else {
          if (widget.role == 'patient') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const PatientHubScreen()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const StaffHubScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid OTP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Sent to: \${widget.maskedEmail}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
