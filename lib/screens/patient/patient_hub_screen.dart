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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHome(context, authProvider, isArabic),
            const ChatbotScreen(),
            const RecordsScreen(),
            ProfileScreen(
              onLanguageChanged: widget.onLanguageChanged,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
    );
  }

  Widget _buildHome(
    BuildContext context,
    AuthProvider authProvider,
    bool isArabic,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? "مرحباً بعودتك،" : "Welcome back,",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      authProvider.userName ?? "User",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    ),
                  ],
                ),
              ),
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
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            isArabic ? "الإجراءات السريعة" : "Quick Actions",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          _actionRow(
            _quickActionCard(
              icon: Icons.medical_services_outlined,
              iconColor: Colors.teal,
              title: isArabic ? "الإبلاغ عن الأعراض" : "Report Symptoms",
              subtitle: isArabic ? "افحص حالتك من المنزل" : "Check from home",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TriagePathScreen(),
                  ),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.location_on_outlined,
              iconColor: Colors.blue,
              title: isArabic ? "لقد وصلت" : "I Have Arrived",
              subtitle: isArabic ? "تجنب الانتظار" : "Skip the queue",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ArrivalCheckInScreen(),
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
              title: isArabic ? "حجز موعد" : "Book Appointment",
              subtitle: isArabic ? "حدد موعد زيارة" : "Schedule a visit",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookAppointmentScreen(),
                  ),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.video_call_outlined,
              iconColor: Colors.indigo,
              title: isArabic ? "استشارة عن بعد" : "Consult Online",
              subtitle: isArabic ? "تحدث مع طبيب" : "Talk to a doctor",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnlineConsultationScreen(),
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
              title: isArabic ? "متتبع الأدوية" : "Medication Tracker",
              subtitle: isArabic ? "عرض الوصفات الطبية" : "View prescriptions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicationTrackerScreen(),
                  ),
                );
              },
            ),
            _quickActionCard(
              icon: Icons.payment_outlined,
              iconColor: Colors.green,
              title: isArabic ? "بوابة الدفع" : "Payment Portal",
              subtitle: isArabic ? "عرض ودفع الفواتير" : "View & pay bills",
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
    );
  }

  Widget _actionRow(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal.withOpacity(0.15),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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