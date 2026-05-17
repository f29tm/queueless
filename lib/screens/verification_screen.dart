import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:queueless/screens/patient/patient_hub_screen.dart';
import 'package:queueless/screens/staff/staff_hub_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/email_sender.dart';

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

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isVerifying = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    currentOtp = widget.otp;
    currentExpireTime = widget.expireTime;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final remaining = currentExpireTime - DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = (remaining / 1000).ceil().clamp(0, 120);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining <= 0) {
        t.cancel();
        setState(() {});
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _timerText {
    if (_secondsRemaining <= 0) return 'Code expired';
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isExpired => _secondsRemaining <= 0;

  Future<void> _resendCode() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final newOtp =
          (100000 + Random().nextInt(900000)).toString();
      final newExpire =
          DateTime.now().millisecondsSinceEpoch + 120000;

      await EmailSender.sendEmail(
        toEmail: widget.email,
        subject: 'QueueLess — New Verification Code',
        otp: newOtp,
      );

      currentOtp = newOtp;
      currentExpireTime = newExpire;
      otpController.clear();
      _startCountdown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A new code has been sent to your email.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to send code. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void verifyOtp() async {
    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Code expired. Please request a new one.')),
      );
      return;
    }

    if (otpController.text.trim() != currentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect code. Please try again.')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
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
        const SnackBar(content: Text('Verification successful!')),
      );

      if (widget.isReset) {
        // reset flow — caller handles navigation
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Verification failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
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
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
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
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Countdown timer
              Text(
                _timerText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isExpired ? Colors.red : Colors.teal,
                ),
              ),

              const SizedBox(height: 28),

              // Verify button
              ElevatedButton(
                onPressed: (_isVerifying || _isExpired) ? null : verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(fontSize: 18),
                      ),
              ),

              const SizedBox(height: 16),

              // Resend button — active only after expiry
              TextButton(
                onPressed: _isExpired && !_isSending ? _resendCode : null,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.teal),
                      )
                    : Text(
                        _isExpired
                            ? 'Resend Code'
                            : 'Resend available after timer expires',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isExpired
                              ? Colors.teal
                              : Colors.grey.shade400,
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
