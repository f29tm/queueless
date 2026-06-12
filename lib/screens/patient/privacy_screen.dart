import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isArabic ? 'الخصوصية وحماية البيانات' : 'Privacy & Data',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'بياناتك في أمان' : 'Your Data is Safe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'نحن نحترم خصوصيتك ونحمي معلوماتك الصحية'
                      : 'We respect your privacy and protect your health information',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _section(
            context,
            icon: Icons.person_outline,
            title: isArabic ? 'البيانات التي نجمعها' : 'Data We Collect',
            items: isArabic
                ? [
                    'الاسم والعمر والجنس',
                    'الأعراض والشكاوى الصحية المُدخلة',
                    'نتائج الفرز الطبي بالذكاء الاصطناعي',
                    'مواعيد الوصول وبيانات الطابور',
                    'تاريخ المواعيد والاستشارات',
                  ]
                : [
                    'Name, age and gender',
                    'Entered symptoms and health complaints',
                    'AI triage assessment results',
                    'Arrival times and queue data',
                    'Appointment and consultation history',
                  ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            icon: Icons.medical_services_outlined,
            title: isArabic ? 'كيف نستخدم بياناتك' : 'How We Use Your Data',
            items: isArabic
                ? [
                    'تقديم خدمة الفرز الطبي المدعومة بالذكاء الاصطناعي',
                    'إدارة طابور الانتظار في قسم الطوارئ',
                    'إرسال إشعارات متعلقة بحالتك',
                    'تحسين دقة النموذج وجودة الخدمة',
                  ]
                : [
                    'Providing AI-powered triage assessment',
                    'Managing the emergency department queue',
                    'Sending notifications related to your status',
                    'Improving model accuracy and service quality',
                  ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            icon: Icons.lock_outline,
            title: isArabic ? 'أمان البيانات' : 'Data Security',
            items: isArabic
                ? [
                    'جميع البيانات مشفرة أثناء النقل والتخزين',
                    'نستخدم Firebase من Google لتخزين آمن ومعتمد',
                    'لا تُشارك بياناتك مع أطراف ثالثة',
                    'يتم الوصول إلى بياناتك من قِبَل فريق الرعاية الصحية فقط',
                  ]
                : [
                    'All data is encrypted in transit and at rest',
                    'We use Google Firebase for secure, certified storage',
                    'Your data is never shared with third parties',
                    'Only your healthcare team can access your records',
                  ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            icon: Icons.verified_user_outlined,
            title: isArabic ? 'حقوقك' : 'Your Rights',
            items: isArabic
                ? [
                    'يحق لك الاطلاع على بياناتك في أي وقت',
                    'يمكنك طلب تصحيح أي معلومات غير دقيقة',
                    'يحق لك طلب حذف حسابك وبياناتك',
                    'يمكنك إلغاء الاشتراك في الإشعارات من الإعدادات',
                  ]
                : [
                    'You can view your data at any time',
                    'You can request correction of inaccurate information',
                    'You have the right to request account and data deletion',
                    'You can opt out of notifications in settings',
                  ],
          ),

          const SizedBox(height: 24),

          // Contact for privacy
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.teal),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'للاستفسارات المتعلقة بالخصوصية'
                            : 'Privacy inquiries',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'privacy@queueless.ae',
                        style: TextStyle(color: Colors.teal, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            isArabic ? 'آخر تحديث: يونيو 2026' : 'Last updated: June 2026',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
