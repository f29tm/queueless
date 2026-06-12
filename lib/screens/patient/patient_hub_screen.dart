import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/triage_levels.dart';
import '../../utils/wait_estimator.dart';

import 'queue_status_card.dart';
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

  const PatientHubScreen({super.key, this.onLanguageChanged});

  @override
  State<PatientHubScreen> createState() => _PatientHubScreenState();
}

class _PatientHubScreenState extends State<PatientHubScreen> {
  int _selectedIndex = 0;

  // ── Live queue banner ───────────────────────────────────────────────────────
  // Watches the patient's own queue doc for position/status changes and shows
  // a slide-in banner so the patient sees movement in the queue immediately —
  // without having to check the notification bell.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSub;
  int? _prevPosition;
  String? _prevStatus;

  String? _bannerMessage;
  bool _bannerVisible = false;
  Timer? _bannerTimer;

  void _startQueueListener(String uid) {
    _queueSub?.cancel();
    _queueSub = FirebaseFirestore.instance
        .collection('queue')
        .where('patientId', isEqualTo: uid)
        .where('status', whereIn: ['waiting_nurse', 'waiting_doctor'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
          if (!mounted || snap.docs.isEmpty) return;
          final data = snap.docs.first.data();
          final newPos = (data['currentPosition'] as num?)?.toInt();
          final newStatus = data['status'] as String?;
          final level = (data['triageLevel'] as String?) ?? TriageLevels.low;
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';

          // Prefer the staff-computed wait (sums the actual acuities ahead);
          // fall back to a same-level estimate while it hasn't landed yet.
          final estMin = (data['estimatedWaitMinutes'] as num?)?.toInt();
          String waitFor(int pos) => (estMin != null && estMin > 0)
              ? '${WaitEstimator.rangeLow(estMin)}–${WaitEstimator.rangeHigh(estMin)} min'
              : WaitEstimator.waitText(level, (pos - 1).clamp(0, 99));

          String? msg;

          // Patient moved to doctor queue (nurse finalized them).
          if (_prevStatus == 'waiting_nurse' && newStatus == 'waiting_doctor') {
            msg = isArabic
                ? 'اكتمل تقييم الممرضة — سيراك طبيب قريباً!'
                : 'Nurse assessment complete — a doctor will see you shortly!';
          }
          // Any position change while waiting — up, down, or first assignment.
          else if (_prevStatus == 'waiting_nurse' &&
              newStatus == 'waiting_nurse' &&
              newPos != null &&
              newPos != _prevPosition) {
            if (newPos <= 1) {
              msg = isArabic
                  ? 'حان دورك — الممرضة جاهزة لرؤيتك الآن!'
                  : "It's your turn — the nurse is ready for you now!";
            } else if (newPos == 2) {
              msg = isArabic
                  ? 'أنت التالي! كن مستعداً.'
                  : "You're next! Please be ready.";
            } else if (_prevPosition != null && newPos > _prevPosition!) {
              // Pushed back: a more urgent patient entered the lane ahead.
              msg = isArabic
                  ? 'تمت أولوية حالة أكثر إلحاحاً — موقعك الآن #$newPos — '
                        'وقت انتظار متوقع: ${waitFor(newPos)}'
                  : 'A more urgent patient was prioritized — you are now #$newPos '
                        '— Est. wait: ${waitFor(newPos)}';
            } else if (_prevPosition == null) {
              // First assignment right after check-in.
              msg = isArabic
                  ? 'موقعك في الطابور #$newPos — وقت انتظار متوقع: ${waitFor(newPos)}'
                  : "You're #$newPos in the queue — Est. wait: ${waitFor(newPos)}";
            } else {
              msg = isArabic
                  ? 'تقدّمت في الطابور! موقعك الآن #$newPos — وقت انتظار متوقع: ${waitFor(newPos)}'
                  : 'Queue update: you moved up to #$newPos — Est. wait: ${waitFor(newPos)}';
            }
          }

          _prevPosition = newPos;
          _prevStatus = newStatus;

          if (msg != null) _showBanner(msg);
        });
  }

  void _showBanner(String message) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerMessage = message;
      _bannerVisible = true;
    });
    _bannerTimer = Timer(const Duration(seconds: 6), _dismissBanner);
  }

  void _dismissBanner() {
    if (mounted) setState(() => _bannerVisible = false);
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

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
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.language,
                    color: Colors.teal,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isArabic ? 'اختر لغة التطبيق' : 'Choose App Language',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
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
                  flag: '🇬🇧',
                  title: 'English',
                  subtitle: 'Use QueueLess in English',
                  value: 'en',
                  selected: selected,
                  onTap: () => setModal(() => selected = 'en'),
                ),
                const SizedBox(height: 12),
                _langOption(
                  flag: '🇦🇪',
                  title: 'العربية',
                  subtitle: 'استخدم QueueLess باللغة العربية',
                  value: 'ar',
                  selected: selected,
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isArabic ? 'تطبيق اللغة' : 'Apply Language',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
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

    return Scaffold(
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
    );
  }

  Widget _buildHome(
    BuildContext context,
    AuthProvider authProvider,
    bool isArabic,
  ) {
    // Start the queue position listener once we have a uid.
    final uid = authProvider.userId;
    if (uid != null && uid.isNotEmpty && _queueSub == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startQueueListener(uid),
      );
    }

    return Stack(
        children: [
          SingleChildScrollView(
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
                            isArabic ? "مرحباً بعودتك،" : "Welcome back,",
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
                                    builder: (_) => const NotificationsScreen(),
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

                const SizedBox(height: 20),

                // Live queue status — driven by the patient's own queue doc (the only one
                // Firestore rules let them read). currentPosition is fanned out by staff.
                _buildQueueStatusCard(context, authProvider, isArabic),

                const SizedBox(height: 8),

                Align(
                  alignment: isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    isArabic ? "الإجراءات السريعة" : "Quick Actions",
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
                    title: isArabic ? "الإبلاغ عن الأعراض" : "Report Symptoms",
                    subtitle: isArabic
                        ? "افحص حالتك من المنزل"
                        : "Check from home",
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
                    subtitle: isArabic
                        ? "عرض الوصفات الطبية"
                        : "View prescriptions",
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
                    subtitle: isArabic
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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

          // ── Live queue banner ──────────────────────────────────────────────
          // Slides in from the top when another patient's finalization pushes
          // this patient's position up. Auto-dismisses after 6 seconds.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: _bannerVisible ? 0 : -100,
            left: 0,
            right: 0,
            child: _QueueBanner(
              message: _bannerMessage ?? '',
              onDismiss: _dismissBanner,
              isArabic: isArabic,
            ),
          ),
        ],
    );
  }

  /// Live status card fed by the patient's single most-recent active queue doc.
  /// Hidden entirely when there is no active doc, so the hub falls back to its
  /// normal layout.
  Widget _buildQueueStatusCard(
    BuildContext context,
    AuthProvider authProvider,
    bool isArabic,
  ) {
    final uid = authProvider.userId;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('queue')
          .where('patientId', isEqualTo: uid)
          .where(
            'status',
            whereIn: ['pre_arrival', 'waiting_nurse', 'waiting_doctor'],
          )
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.docs.first.data();
        return QueueStatusCard(
          data: data,
          isArabic: isArabic,
          onCheckIn: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArrivalCheckInScreen()),
            );
          },
        );
      },
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
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
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

// ── Queue position banner ─────────────────────────────────────────────────────

/// Dismissible top banner that slides in when the patient's queue position
/// changes (another patient was finalized or discharged ahead of them).
/// Lives in a Stack at the top of the home tab so it floats above all content.
class _QueueBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final bool isArabic;

  const _QueueBanner({
    required this.message,
    required this.onDismiss,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
    );
  }
}
