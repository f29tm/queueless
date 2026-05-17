import 'package:flutter/material.dart';

class ManualCheckinConfirmationScreen extends StatelessWidget {
  const ManualCheckinConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>;
    final queueNumber = args['queueNumber'] as String? ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("You're Registered"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Checkmark icon
              const Icon(Icons.check_circle,
                  color: Colors.teal, size: 80),

              const SizedBox(height: 20),

              const Text(
                "You're in the queue!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              // Queue number box
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: Text(
                  queueNumber,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                    letterSpacing: 4,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "Show this number at the reception desk when you arrive.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.4),
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "What happens next?",
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),

              _stepItem(
                icon: Icons.directions_walk,
                text: "Come to the emergency department",
              ),
              const SizedBox(height: 12),
              _stepItem(
                icon: Icons.medical_services_outlined,
                text:
                    "The nurse will assess your symptoms on arrival",
              ),
              const SizedBox(height: 12),
              _stepItem(
                icon: Icons.queue,
                text: "You'll be added to the priority queue",
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/patient-hub',
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Got it — Go Home",
                    style: TextStyle(fontSize: 17, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.teal, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
