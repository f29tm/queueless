import 'package:flutter/material.dart';
import '../../services/triage_service.dart';
import 'arrival_checkin_screen.dart';
import '../../utils/app_localizer.dart';

// Mirror of symptom_assessment_screen translations for display
const Map<String, String> _symptomAr = {
  "Chest pain": "ألم في الصدر",
  "Chest tightness": "ضيق في الصدر",
  "Shortness of breath": "ضيق في التنفس",
  "Heart palpitations": "خفقان القلب",
  "Radiating jaw pain": "ألم يمتد للفك",
  "Headache": "صداع",
  "Seizures": "نوبات تشنجية",
  "Dizziness": "دوخة",
  "Vision changes": "تغيرات في الرؤية",
  "Confusion": "ارتباك",
  "Weakness": "ضعف",
  "Numbness": "تخدر",
  "Wheezing": "صفير في التنفس",
  "Coughing blood": "سعال بالدم",
  "Persistent cough": "سعال مستمر",
  "Sore throat": "التهاب الحلق",
  "Trouble breathing": "صعوبة في التنفس",
  "Abdominal pain": "ألم في البطن",
  "Vomiting": "قيء",
  "Persistent vomiting": "قيء مستمر",
  "Diarrhea": "إسهال",
  "Blood in stool": "دم في البراز",
  "Bloating": "انتفاخ",
  "Fever": "حمى",
  "Fatigue": "إرهاق",
  "Body aches": "آلام جسدية",
  "Weight loss": "فقدان الوزن",
  "Fracture": "كسر",
  "Joint swelling": "تورم المفاصل",
  "Muscle spasms": "تشنج عضلي",
  "Back pain": "ألم الظهر",
  "Anxiety": "قلق",
  "Depressed mood": "مزاج مكتئب",
  "Memory issues": "مشاكل في الذاكرة",
};

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

  String _label(bool isArabic) {
    switch (triageResult.prediction) {
      case 'Emergency':
        return isArabic ? 'طارئ' : 'Emergency';
      case 'Urgent':
        return isArabic ? 'عاجل' : 'Urgent';
      default:
        return isArabic ? 'غير عاجل' : 'Non-Urgent';
    }
  }

  String _message(bool isArabic) {
    switch (triageResult.prediction) {
      case 'Emergency':
        return isArabic
            ? 'تشير أعراضك إلى حالة طبية طارئة. يرجى التوجه فوراً إلى أقرب قسم طوارئ.'
            : 'Your symptoms indicate a potential medical emergency. Please go to the nearest Emergency Department immediately.';
      case 'Urgent':
        return isArabic
            ? 'تحتاج أعراضك إلى تقييم سريع. يرجى التوجه إلى المستشفى في أقرب وقت ممكن.'
            : 'Your symptoms need prompt evaluation. Please proceed to the hospital as soon as possible.';
      default:
        return isArabic
            ? 'تبدو أعراضك غير عاجلة. يمكنك التوجه إلى المستشفى في الوقت المناسب لك.'
            : 'Your symptoms appear to be non-urgent. You may proceed to the hospital at your convenience.';
    }
  }

  String _waitTime(bool isArabic) {
    if (triageResult.prediction == 'Emergency') {
      return isArabic ? 'فوري' : 'Immediate';
    }
    return isArabic ? 'يظهر بعد تسجيل الوصول' : 'Shown after check-in';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: AppLocalizer.direction(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6FA),
          elevation: 0,
          foregroundColor: Colors.black87,
          title: Text(
            isArabic ? 'نتيجة التقييم' : 'Assessment Result',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
        ),
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
                        _label(isArabic),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _message(isArabic),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // AI Confidence card removed — confidence/entropy are internal
              // signals and must never be surfaced to the patient.

                // WAIT TIME INFO CARD
                _card([
                  _infoRow(
                    Icons.timer_outlined,
                    isArabic ? "وقت الانتظار المتوقع" : "Estimated Wait",
                    _waitTime(isArabic),
                  ),
                  const Divider(height: 24),
                  _infoRow(
                    Icons.local_hospital,
                    isArabic ? "مستوى الأولوية" : "Priority Level",
                    _label(isArabic),
                  ),
                ]),

                // REPORTED SYMPTOMS
                if (selectedSymptoms.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    isArabic ? "الأعراض المُبلَّغ عنها" : "Reported Symptoms",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  _symptomList(isArabic),
                ],

                const SizedBox(height: 32),

                // EMERGENCY WARNING
                if (triageResult.prediction == 'Emergency') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.red.shade300, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.emergency,
                            color: Colors.red.shade700, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isArabic
                                ? "إذا كنت تعاني من ضائقة شديدة أو غير قادر على التحرك، اتصل بـ 999 فوراً. لا تنتظر."
                                : "If you are in severe distress or unable to move, call 999 immediately. Do not wait.",
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
                        builder: (_) => Directionality(
                          textDirection: AppLocalizer.direction(context),
                          child: AlertDialog(
                            title: Text(
                                isArabic ? "حالة طارئة" : "Emergency"),
                            content: Text(isArabic
                                ? "يرجى الاتصال بـ 999 أو التوجه فوراً إلى أقرب قسم طوارئ."
                                : "Please call 999 or proceed to the nearest Emergency Department immediately."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(isArabic ? "حسناً" : "OK"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text(
                        isArabic
                            ? "اتصل بالطوارئ (999)"
                            : "Call Emergency Services (999)",
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
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
                      label: Text(isArabic
                          ? "لقد وصلت إلى المستشفى"
                          : "I Have Arrived at the Hospital"),
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
                      icon: const Icon(Icons.location_on,
                          color: Colors.white),
                      label: Text(
                        isArabic
                            ? "لقد وصلت إلى المستشفى"
                            : "I Have Arrived at the Hospital",
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      isArabic
                          ? "الوصول لاحقاً — العودة للرئيسية"
                          : "Arrive later — back to home",
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
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
            color: Colors.grey.withValues(alpha: 0.12),
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

  Widget _symptomList(bool isArabic) {
    return Column(
      children: selectedSymptoms.map((s) {
        final display = isArabic ? (_symptomAr[s] ?? s) : s;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.brightness_1,
                  size: 10, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(display,
                    style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
