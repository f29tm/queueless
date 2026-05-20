import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ArrivalCheckInScreen extends StatefulWidget {
  final String? queueDocId;

  const ArrivalCheckInScreen({super.key, this.queueDocId});

  @override
  State<ArrivalCheckInScreen> createState() => _ArrivalCheckInScreenState();
}

class _ArrivalCheckInScreenState extends State<ArrivalCheckInScreen> {
  bool _isConfirming = false;
  bool _confirmed = false;
  String? _resolvedDocId;
  String _queueNumber = '-';
  int? _waitPosition;
  int? _estimatedWaitMinutes;

  static const int _avgServiceMinutes = 15;

  @override
  void initState() {
    super.initState();
    _resolvedDocId = widget.queueDocId;
    if (_resolvedDocId == null) {
      _lookupPendingDoc();
    }
  }

  Future<void> _lookupPendingDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('queue')
          .where('patientId', isEqualTo: uid)
          .where('status', isEqualTo: 'pre_arrival')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty && mounted) {
        setState(() => _resolvedDocId = query.docs.first.id);
      }
    } catch (_) {}
  }

  Future<void> _confirmArrival() async {
    if (_resolvedDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "No pending triage found. Complete symptom assessment first."),
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('queue')
          .doc(_resolvedDocId);
      final existingDoc = await docRef.get();
      final existingData = existingDoc.data();
      final queueNumber = existingData?['queueNumber'] as String? ??
          'Q${_resolvedDocId!.substring(0, 6).toUpperCase()}';

      await FirebaseFirestore.instance
          .collection('queue')
          .doc(_resolvedDocId)
          .update({
        'queueType': 'nurse',
        'status': 'waiting_nurse',
        'queueNumber': queueNumber,
        'arrivedAt': FieldValue.serverTimestamp(),
      });

      final waiting = await FirebaseFirestore.instance
          .collection('queue')
          .where('queueType', isEqualTo: 'nurse')
          .where('status', isEqualTo: 'waiting_nurse')
          .orderBy('priorityNumber')
          .orderBy('createdAt')
          .get();
      final index = waiting.docs.indexWhere((doc) => doc.id == _resolvedDocId);
      final patientsAhead = index < 0 ? 0 : index;

      if (mounted) {
        setState(() {
          _confirmed = true;
          _queueNumber = queueNumber;
          _waitPosition = patientsAhead + 1;
          _estimatedWaitMinutes = patientsAhead * _avgServiceMinutes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in failed. Please try again at reception."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _confirmed ? _buildSuccessState() : _buildPreConfirmState(),
      ),
    );
  }

  // ── POST-CONFIRM ────────────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200, width: 3),
              ),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 64),
            ),
            const SizedBox(height: 28),
            const Text(
              "You're checked in!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "A nurse will see you shortly. Please take a seat in the waiting area.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    "Your Queue Number",
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _queueNumber,
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _queueInfo(
                          "Position",
                          _waitPosition == null ? "-" : "#$_waitPosition",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _queueInfo(
                          "Estimated Wait",
                          _estimatedWaitMinutes == null
                              ? "-"
                              : _estimatedWaitMinutes == 0
                                  ? "Next"
                                  : "$_estimatedWaitMinutes min",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Back to Home",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── PRE-CONFIRM ─────────────────────────────────────────────────────────────

  Widget _buildPreConfirmState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "I Have Arrived",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          const Text(
            "Already at the hospital? Check in here to skip the reception queue.",
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 40),

          // Location icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.teal.withOpacity(0.3),
                  width: 4,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.teal.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.teal,
                  size: 40,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Confirm arrival button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmArrival,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.pan_tool, size: 22),
              label: Text(
                _isConfirming ? "Checking in…" : "I Have Arrived",
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              "Tap to manually check in at the hospital",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "OR",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 26),

          // Auto-detect card — GPS not yet implemented
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.teal),
                      SizedBox(width: 12),
                      Text(
                        "Auto-Detect Location",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Enable GPS to automatically detect when you're near the hospital for instant check-in.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.location_searching,
                          color: Colors.teal),
                      label: const Text(
                        "Coming Soon",
                        style: TextStyle(color: Colors.teal),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.teal.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Use this when you arrive at the hospital after completing your symptom assessment. No need to wait at the reception desk.",
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
