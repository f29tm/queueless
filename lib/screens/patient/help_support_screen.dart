import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final faqs = isArabic
        ? [
            _FAQ(
              q: 'كيف يعمل الفرز الطبي بالذكاء الاصطناعي؟',
              a: 'يقوم نموذج الذكاء الاصطناعي بتحليل الأعراض التي تدخلها ويصنفها إلى ثلاث درجات: طارئ، عاجل، أو غير عاجل. يساعد ذلك فريق الطوارئ في تحديد أولويات الحالات.',
            ),
            _FAQ(
              q: 'هل نتيجة الفرز نهائية؟',
              a: 'لا. النتيجة هي تقدير أولي فقط. الممرضة والطبيب سيقومان بتقييم حالتك عند وصولك للتأكيد النهائي.',
            ),
            _FAQ(
              q: 'كيف أتحقق من موعدي؟',
              a: 'اذهب إلى تبويب "السجلات" في الشريط السفلي. ستجد جميع مواعيدك واستشاراتك هناك.',
            ),
            _FAQ(
              q: 'هل يمكنني إلغاء موعدي؟',
              a: 'نعم. في شاشة "السجلات"، اضغط على أيقونة الإلغاء بجانب الموعد المطلوب. سيتم إشعار الطبيب تلقائياً.',
            ),
            _FAQ(
              q: 'ماذا أفعل إذا كانت حالتي طارئة؟',
              a: 'اتصل فوراً بالإسعاف على الرقم 999. لا تنتظر. التطبيق مخصص للحالات التي يمكنك التحرك فيها بأمان.',
            ),
            _FAQ(
              q: 'هل بياناتي الطبية آمنة؟',
              a: 'نعم. يتم تخزين جميع بياناتك بشكل مشفر على خوادم Firebase المعتمدة. لا تُشارك بياناتك مع أي طرف ثالث.',
            ),
            _FAQ(
              q: 'كيف أغير لغة التطبيق؟',
              a: 'اضغط على أيقونة الكرة الأرضية في الصفحة الرئيسية، أو اذهب إلى الملف الشخصي ← الإعدادات ← اللغة.',
            ),
          ]
        : [
            _FAQ(
              q: 'How does the AI triage work?',
              a: 'Our AI model analyses your entered symptoms and classifies them as Emergency, Urgent, or Non-Urgent. This helps the ED team prioritise cases before you even arrive.',
            ),
            _FAQ(
              q: 'Is the triage result final?',
              a: 'No. It is a preliminary estimate only. The nurse and doctor will conduct a full assessment when you arrive for a final determination.',
            ),
            _FAQ(
              q: 'How do I check my appointments?',
              a: 'Go to the "Records" tab in the bottom navigation bar. All your appointments and consultations are listed there.',
            ),
            _FAQ(
              q: 'Can I cancel an appointment?',
              a: 'Yes. In the Records screen, tap the cancel icon next to the appointment. The doctor will be notified automatically.',
            ),
            _FAQ(
              q: 'What if my condition is an emergency?',
              a: 'Call 999 immediately. Do not wait. This app is designed for situations where you can safely move on your own.',
            ),
            _FAQ(
              q: 'Is my medical data secure?',
              a: 'Yes. All your data is encrypted and stored on certified Firebase servers. It is never shared with third parties.',
            ),
            _FAQ(
              q: 'How do I change the app language?',
              a: 'Tap the globe icon on the home screen, or go to Profile → Settings → Language.',
            ),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isArabic ? 'المساعدة والدعم' : 'Help & Support',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Emergency banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency, color: Colors.red.shade700, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'في حالات الطوارئ اتصل بـ 999 فوراً'
                        : 'For life-threatening emergencies call 999',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FAQ section
          Text(
            isArabic ? 'الأسئلة الشائعة' : 'Frequently Asked Questions',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ...faqs.map((faq) => _FaqTile(faq: faq)),

          const SizedBox(height: 28),

          // Contact section
          Text(
            isArabic ? 'تواصل معنا' : 'Contact Us',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _contactTile(
            icon: Icons.email_outlined,
            iconColor: Colors.teal,
            label: isArabic ? 'البريد الإلكتروني' : 'Email',
            value: 'support@queueless.ae',
          ),

          const SizedBox(height: 10),

          _contactTile(
            icon: Icons.phone_outlined,
            iconColor: Colors.blue,
            label: isArabic ? 'هاتف الدعم' : 'Support Line',
            value: '+971 2 000 0000',
          ),

          const SizedBox(height: 10),

          _contactTile(
            icon: Icons.schedule_outlined,
            iconColor: Colors.orange,
            label: isArabic ? 'ساعات الدعم' : 'Support Hours',
            value: isArabic
                ? 'الأحد – الخميس، 8ص – 5م'
                : 'Sun – Thu, 8 AM – 5 PM',
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FAQ {
  final String q;
  final String a;
  const _FAQ({required this.q, required this.a});
}

class _FaqTile extends StatefulWidget {
  final _FAQ faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.q,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  widget.faq.a,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
