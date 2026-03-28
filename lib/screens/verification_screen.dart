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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Please enter the 6-digit code sent to your email.',
                style: TextStyle(fontSize: 15, color: Color(0xFF444444)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.maskedEmail,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '••••••',
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '02:00', // Mock timer, could be implemented correctly later
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Verify',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Resend code logic
                },
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A73E8),
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
