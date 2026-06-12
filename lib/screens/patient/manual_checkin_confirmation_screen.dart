import 'package:flutter/material.dart';

class ManualCheckinConfirmationScreen extends StatelessWidget {
  const ManualCheckinConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
          title: Text(isArabic ? "تم تسجيلك" : "You're Registered"),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                const Icon(Icons.check_circle, color: Colors.teal, size: 80),

                const SizedBox(height: 20),

                Text(
                  isArabic ? "أنت في قائمة الانتظار!" : "You're in the queue!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.teal.shade200, width: 2),
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
                  isArabic
                      ? "تم إخطار الممرضة. توجّه إلى قسم الطوارئ الآن."
                      : "The nurse has been notified. Please head to the emergency department now.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.4),
                ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),

                Align(
                  alignment: isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    isArabic ? "ماذا يحدث بعد ذلك؟" : "What happens next?",
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 16),

                _stepItem(
                  icon: Icons.directions_walk,
                  text: isArabic
                      ? "توجّه إلى قسم الطوارئ الآن"
                      : "Head to the emergency department now",
                  isArabic: isArabic,
                ),
                const SizedBox(height: 12),
                _stepItem(
                  icon: Icons.medical_services_outlined,
                  text: isArabic
                      ? "ستقوم الممرضة بتقييم أعراضك عند وصولك"
                      : "The nurse will assess your symptoms on arrival",
                  isArabic: isArabic,
                ),
                const SizedBox(height: 12),
                _stepItem(
                  icon: Icons.queue,
                  text: isArabic
                      ? "سيتم إضافتك إلى قائمة الأولويات"
                      : "You'll be added to the priority queue",
                  isArabic: isArabic,
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      isArabic ? "حسناً — العودة للرئيسية" : "Got it — Go Home",
                      style: const TextStyle(
                          fontSize: 17, color: Colors.white),
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

  Widget _stepItem({
    required IconData icon,
    required String text,
    required bool isArabic,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
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
