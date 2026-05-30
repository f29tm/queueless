import 'package:flutter/material.dart';
import '../../services/triage_service.dart';
import 'arrival_checkin_screen.dart';

class SymptomResultScreen extends StatelessWidget {
  final TriageResult triageResult;
  final String queueDocId;
  final List<String> selectedSymptoms;

  const SymptomResultScreen({
    super.key,
    required this.triageResult,
    required this.queueDocId,
    required this.selectedSymptoms,
  });

  Color get _color {
    switch (triageResult.prediction) {
      case 'Emergency':
        return Colors.red;
      case 'Urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData get _icon {
    switch (triageResult.prediction) {
      case 'Emergency':
        return Icons.error_outline;
      case 'Urgent':
        return Icons.report;
      default:
        return Icons.check_circle;
    }
  }

  String get _label {
    switch (triageResult.prediction) {
      case 'Emergency':
        return 'Emergency';
      case 'Urgent':
        return 'Urgent';
      default:
        return 'Non-Urgent';
    }
  }

  String get _message {
    switch (triageResult.prediction) {
      case 'Emergency':
        return 'Your symptoms indicate a potential medical emergency. Please go to the nearest Emergency Department immediately.';
      case 'Urgent':
        return 'Your symptoms need prompt evaluation. Please proceed to the hospital as soon as possible.';
      default:
        return 'Your symptoms appear to be non-urgent. You may proceed to the hospital at your convenience.';
    }
  }

  String get _waitTime {
    if (triageResult.prediction == 'Emergency') return 'Immediate';
    return 'Shown after check-in';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // SEVERITY BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Icon(_icon, color: Colors.white, size: 60),
                    const SizedBox(height: 12),
                    Text(
                      _label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // WAIT TIME INFO CARD
              _card([
                _infoRow(
                    Icons.timer_outlined, "Estimated Wait", _waitTime),
                const Divider(height: 24),
                _infoRow(Icons.local_hospital, "Priority Level", _label),
              ]),

              // REPORTED SYMPTOMS
              if (selectedSymptoms.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text(
                  "Reported Symptoms",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _symptomList(),
              ],

              const SizedBox(height: 32),

              // EMERGENCY WARNING — shown only for Emergency patients
              if (triageResult.prediction == 'Emergency') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.emergency, color: Colors.red.shade700, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "If you are in severe distress or unable to move, call 999 immediately. Do not wait.",
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // PRIMARY ACTION
              if (triageResult.prediction == 'Emergency') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Emergency"),
                        content: const Text(
                            "Please call 999 or proceed to the nearest Emergency Department immediately."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text(
                      "Call Emergency Services (999)",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ArrivalCheckInScreen(queueDocId: queueDocId),
                      ),
                    ),
                    icon: const Icon(Icons.location_on),
                    label: const Text("I Have Arrived at the Hospital"),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ArrivalCheckInScreen(queueDocId: queueDocId),
                      ),
                    ),
                    icon: const Icon(Icons.location_on, color: Colors.white),
                    label: const Text(
                      "I Have Arrived at the Hospital",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // SECONDARY ACTION — arrive later
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Arrive later — back to home",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.grey.withOpacity(0.12),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
        const Spacer(),
        Text(value,
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _symptomList() {
    return Column(
      children: selectedSymptoms.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.grey.withOpacity(0.1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.brightness_1,
                  size: 10, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(s,
                      style: const TextStyle(fontSize: 15))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
