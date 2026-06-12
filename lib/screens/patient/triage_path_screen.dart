import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizer.dart';
import '../../services/notification_service.dart';

class TriagePathScreen extends StatefulWidget {
  const TriagePathScreen({super.key});

  @override
  State<TriagePathScreen> createState() => _TriagePathScreenState();
}

class _TriagePathScreenState extends State<TriagePathScreen> {
  bool _isCreating = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  Future<void> _createManualQueueEntry() async {
    setState(() => _isCreating = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showError(
          _isArabic
              ? "يجب تسجيل الدخول للمتابعة."
              : "You must be logged in to continue.",
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (userDoc.data()?['name'] as String?) ?? 'Unknown Patient';

      final queueNumber =
          'Q${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // Immediately place patient in nurse queue — no second check-in needed.
      await FirebaseFirestore.instance.collection('queue').add({
        'patientId': uid,
        'patientName': name,
        'triageLevel': 'PENDING',
        'triageMethod': 'manual',
        'queueType': 'nurse',
        'status': 'waiting_nurse',
        'priorityNumber': 3,
        'noAITriage': true,
        'queueNumber': queueNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'arrivedAt': FieldValue.serverTimestamp(),
        'symptoms': [],
        'chiefComplaint': 'To be assessed by nurse',
      });

      // Notify all nurses (best-effort).
      try {
        await NotificationService().notifyNursePatientArrival(
          patientName: name,
          queueNumber: queueNumber,
          reportedSymptoms: false,
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/manual-confirmation',
        arguments: {'queueNumber': queueNumber},
      );
    } catch (_) {
      _showError(
        _isArabic
            ? "حدث خطأ ما. يرجى المحاولة مرة أخرى."
            : "Something went wrong. Please try again.",
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isArabic
              ? "كيف تريد تسجيل الدخول؟"
              : "How would you like to check in?",
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: _isCreating
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    isArabic
                        ? "جارٍ تسجيلك في الطابور…"
                        : "Registering you in the queue…",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? "اختر طريقة الفرز المناسبة لك"
                          : "Choose how you want to be triaged today",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _ChoiceCard(
                      icon: Icons.psychology_outlined,
                      iconColor: Colors.teal,
                      title: isArabic
                          ? "تقييم الأعراض بالذكاء الاصطناعي"
                          : "Assess Symptoms with AI",
                      subtitle: isArabic
                          ? "أجب على بعض الأسئلة واحصل على تقييم طبي قبل وصولك. معالجة أسرع في قسم الطوارئ."
                          : "Answer a few questions and get an urgency rating before you arrive. Faster processing at the ED.",
                      onTap: () =>
                          Navigator.pushNamed(context, '/symptom-assessment'),
                    ),
                    const SizedBox(height: 18),
                    _ChoiceCard(
                      icon: Icons.personal_injury_outlined,
                      iconColor: Colors.grey.shade600,
                      title: isArabic
                          ? "التقرير للممرضة عند الوصول"
                          : "Report to Nurse on Arrival",
                      subtitle: isArabic
                          ? "تخطَّ الاستبيان. تعال وستقوم الممرضة بتقييمك مباشرةً."
                          : "Skip the questionnaire. Come in and the nurse will assess you directly.",
                      onTap: _createManualQueueEntry,
                    ),
                    const Spacer(),
                    Text(
                      isArabic
                          ? "في حالات الطوارئ، اتصل بـ 999 فوراً."
                          : "For emergencies, call 999 immediately.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
