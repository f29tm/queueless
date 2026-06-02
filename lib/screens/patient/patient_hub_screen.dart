import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

import 'arrival_checkin_screen.dart';
import 'triage_path_screen.dart';
import 'medication_tracker_screen.dart';
import 'profile_screen.dart';
import 'records_screen.dart';
import 'book_appointment_screen.dart';
import 'online_consultation_screen.dart';
import 'notifications_screen.dart';
import 'chatbot_screen.dart';

class PatientHubScreen extends StatefulWidget {
  final Future<void> Function(String)? onLanguageChanged;

  const PatientHubScreen({
    super.key,
    this.onLanguageChanged,
  });

  @override
  State<PatientHubScreen> createState() => _PatientHubScreenState();
}

class _PatientHubScreenState extends State<PatientHubScreen> {
  int _selectedIndex = 0;

  void _showLanguageSheet(BuildContext context, bool isArabic) {
    String selected = isArabic ? 'ar' : 'en';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Container(
                  width: 45, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
                  child: const Icon(Icons.language, color: Colors.teal, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  isArabic ? 'اختر لغة التطبيق' : 'Choose App Language',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'يمكنك تغيير اللغة في أي وقت'
                      : 'You can change the language anytime',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _langOption(
                  flag: '🇬🇧', title: 'English',
                  subtitle: 'Use QueueLess in English',
                  value: 'en', selected: selected,
                  onTap: () => setModal(() => selected = 'en'),
                ),
                const SizedBox(height: 12),
                _langOption(
                  flag: '🇦🇪', title: 'العربية',
                  subtitle: 'استخدم QueueLess باللغة العربية',
                  value: 'ar', selected: selected,
                  onTap: () => setModal(() => selected = 'ar'),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onLanguageChanged?.call(selected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isArabic ? 'تطبيق اللغة' : 'Apply Language',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _langOption({
    required String flag,
    required String title,
    required String subtitle,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final bool isSelected = value == selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withValues(alpha: 0.10)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.teal : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.teal : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHome(context, authProvider, isArabic),
              const ChatbotScreen(),
              const RecordsScreen(),
              ProfileScreen(onLanguageChanged: widget.onLanguageChanged),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: isArabic ? "الرئيسية" : "Home",
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble),
              label: isArabic ? "المحادثة" : "Chatbot",
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder),
              label: isArabic ? "السجلات" : "Records",
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: isArabic ? "الملف" : "Profile",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    AuthProvider authProvider,
    bool isArabic,
  ) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
  textDirection: isArabic
      ? TextDirection.rtl
      : TextDirection.ltr,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    /// LOGO
    Image.asset(
      'assets/images/logo.png',
      width: 80,
      height: 80,
    ),

    const SizedBox(width: 16),

    /// NAME + GREETING
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            isArabic
                ? "مرحباً بعودتك،"
                : "Welcome back,",
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            authProvider.userName ?? "User",
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(width: 12),

    /// NOTIFICATION BUTTON
    StreamBuilder<int>(
      stream: NotificationService().unreadCountStream(
        authProvider.userId ?? '',
      ),
      builder: (context, snapshot) {

        final count = snapshot.data ?? 0;

        return Stack(
          children: [

            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const NotificationsScreen(),
                  ),
                );
              },
            ),

            if (count > 0)
              PositionedDirectional(
                top: 5,
                end: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),

    /// LANGUAGE TOGGLE
    IconButton(
      icon: const Icon(Icons.language),
      tooltip: isArabic ? 'تغيير اللغة' : 'Change language',
      onPressed: () => _showLanguageSheet(context, isArabic),
    ),

  ],
),

const SizedBox(height: 28),

Align(
  alignment:
      isArabic
          ? Alignment.centerRight
          : Alignment.centerLeft,
  child: Text(
    isArabic
        ? "الإجراءات السريعة"
        : "Quick Actions",
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
),

const SizedBox(height: 16),

_actionRow(
  _quickActionCard(
    icon: Icons.medical_services_outlined,
    iconColor: Colors.teal,
    title:
        isArabic
            ? "الإبلاغ عن الأعراض"
            : "Report Symptoms",
    subtitle:
        isArabic
            ? "افحص حالتك من المنزل"
            : "Check from home",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const TriagePathScreen(),
        ),
      );
    },
  ),

  _quickActionCard(
    icon: Icons.location_on_outlined,
    iconColor: Colors.blue,
    title:
        isArabic
            ? "لقد وصلت"
            : "I Have Arrived",
    subtitle:
        isArabic
            ? "تجنب الانتظار"
            : "Skip the queue",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const ArrivalCheckInScreen(),
        ),
      );
    },
  ),
),

const SizedBox(height: 14),

_actionRow(
  _quickActionCard(
    icon: Icons.event_available,
    iconColor: Colors.orange,
    title:
        isArabic
            ? "حجز موعد"
            : "Book Appointment",
    subtitle:
        isArabic
            ? "حدد موعد زيارة"
            : "Schedule a visit",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const BookAppointmentScreen(),
        ),
      );
    },
  ),

  _quickActionCard(
    icon: Icons.video_call_outlined,
    iconColor: Colors.indigo,
    title:
        isArabic
            ? "استشارة عن بعد"
            : "Consult Online",
    subtitle:
        isArabic
            ? "تحدث مع طبيب"
            : "Talk to a doctor",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const OnlineConsultationScreen(),
        ),
      );
    },
  ),
),

const SizedBox(height: 14),

_actionRow(
  _quickActionCard(
    icon: Icons.medication_outlined,
    iconColor: Colors.purple,
    title:
        isArabic
            ? "متتبع الأدوية"
            : "Medication Tracker",
    subtitle:
        isArabic
            ? "عرض الوصفات الطبية"
            : "View prescriptions",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const MedicationTrackerScreen(),
        ),
      );
    },
  ),

  _quickActionCard(
    icon: Icons.payment_outlined,
    iconColor: Colors.green,
    title:
        isArabic
            ? "بوابة الدفع"
            : "Payment Portal",
    subtitle:
        isArabic
            ? "عرض ودفع الفواتير"
            : "View & pay bills",
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "بوابة الدفع قريباً"
                : "Payment portal coming soon",
          ),
        ),
      );
    },
  ),
),

            const SizedBox(height: 30),

            Text(
              isArabic ? "كيف يعمل التطبيق" : "How It Works",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),

            const SizedBox(height: 16),

            _howItWorksItem(
              "1",
              isArabic ? "الإبلاغ عن الأعراض" : "Report Symptoms",
              isArabic ? "صف حالتك الصحية" : "Describe how you're feeling",
              Icons.edit,
            ),
            _howItWorksItem(
              "2",
              isArabic ? "الحصول على التقييم" : "Get Assessed",
              isArabic ? "تقييم درجة الخطورة" : "Severity assessment",
              Icons.analytics,
            ),
            _howItWorksItem(
              "3",
              isArabic ? "الوصول وتسجيل الدخول" : "Arrive & Check In",
              isArabic ? "تجنب الانتظار في الطابور" : "Skip the queue",
              Icons.location_on,
            ),
            _howItWorksItem(
              "4",
              isArabic ? "اتبع مسارك" : "Follow Your Path",
              isArabic ? "رعاية خطوة بخطوة" : "Step-by-step care",
              Icons.timeline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(Widget first, Widget second) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Row(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Expanded(child: first),
        const SizedBox(width: 14),
        Expanded(child: second),
      ],
    );
  }
  Widget _quickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksItem(
    String number,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal.withValues(alpha: 0.15),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: Colors.teal),
        ],
      ),
    );
  }
}