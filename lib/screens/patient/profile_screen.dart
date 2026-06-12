import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../login_screen.dart';
import 'privacy_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function(String)? onLanguageChanged;

  const ProfileScreen({super.key, this.onLanguageChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _loadingNotifPref = true;
  final _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingNotifPref = false);
      return;
    }
    final enabled = await _notifService.isNotificationsEnabled(uid);
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _loadingNotifPref = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value, String uid) async {
    setState(() => _notificationsEnabled = value);
    await _notifService.setNotificationsEnabled(uid, value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final uid = auth.currentUser?.uid ?? '';

    final String displayName = auth.userName ?? "User";
    final String displayEmail = auth.currentUser?.email ?? "No email";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? "الملف الشخصي" : "Profile",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 25,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('queue')
                              .where(
                                'patientId',
                                isEqualTo: auth.currentUser?.uid,
                              )
                              .snapshots(),
                          builder: (context, queueSnap) {
                            final queueCount = queueSnap.hasData
                                ? queueSnap.data!.docs.length
                                : 0;

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('appointments')
                                  .where(
                                    'patientId',
                                    isEqualTo: auth.currentUser?.uid,
                                  )
                                  .where('status', isEqualTo: 'completed')
                                  .snapshots(),
                              builder: (context, apptSnap) {
                                final completedApptCount = apptSnap.hasData
                                    ? apptSnap.data!.docs.length
                                    : 0;

                                return _buildCounter(
                                  (queueCount + completedApptCount).toString(),
                                  isArabic ? 'الزيارات' : 'Visits',
                                );
                              },
                            );
                          },
                        ),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('appointments')
                              .where(
                                'patientId',
                                isEqualTo: auth.currentUser?.uid,
                              )
                              .where('status', isEqualTo: 'scheduled')
                              .snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData
                                ? snap.data!.docs.length
                                : 0;
                            return _buildCounter(
                              count.toString(),
                              isArabic ? 'المواعيد' : 'Appointments',
                            );
                          },
                        ),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('consultations')
                              .where(
                                'patientId',
                                isEqualTo: auth.currentUser?.uid,
                              )
                              .where('status', isEqualTo: 'scheduled')
                              .snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData
                                ? snap.data!.docs.length
                                : 0;
                            return _buildCounter(
                              count.toString(),
                              isArabic ? 'الاستشارات' : 'Consultations',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                isArabic ? "الإعدادات" : "SETTINGS",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 12),

              _buildToggleItem(
                icon: Icons.notifications_none,
                label: isArabic ? "الإشعارات" : "Notifications",
                value: _notificationsEnabled,
                loading: _loadingNotifPref,
                onChanged: uid.isNotEmpty
                    ? (v) => _toggleNotifications(v, uid)
                    : null,
              ),

              _buildSettingsItem(
                icon: Icons.language,
                label: isArabic ? "اللغة" : "Language",
                value: isArabic ? "العربية" : "English",
                onTap: () => _showLanguageSheet(context, isArabic),
              ),

              _buildSettingsItem(
                icon: Icons.lock_outline,
                label: isArabic ? "الخصوصية" : "Privacy",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),

              _buildSettingsItem(
                icon: Icons.help_outline,
                label: isArabic ? "المساعدة والدعم" : "Help & Support",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();

                    if (!context.mounted) return;

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    isArabic ? "تسجيل الخروج" : "Sign Out",
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, bool isArabic) {
    String selectedLanguage = isArabic ? 'ar' : 'en';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                      isArabic ? "اختر لغة التطبيق" : "Choose App Language",
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      isArabic
                          ? "يمكنك تغيير اللغة في أي وقت من الإعدادات"
                          : "You can change the language anytime from settings",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _languageOption(
                      title: "English",
                      subtitle: "Use QueueLess in English",
                      flag: "🇬🇧",
                      value: "en",
                      selectedLanguage: selectedLanguage,
                      onTap: () => setModalState(() => selectedLanguage = "en"),
                    ),

                    const SizedBox(height: 12),

                    _languageOption(
                      title: "العربية",
                      subtitle: "استخدم QueueLess باللغة العربية",
                      flag: "🇦🇪",
                      value: "ar",
                      selectedLanguage: selectedLanguage,
                      onTap: () => setModalState(() => selectedLanguage = "ar"),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(sheetContext);

                          if (widget.onLanguageChanged == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Language function is not connected",
                                ),
                              ),
                            );
                            return;
                          }

                          await widget.onLanguageChanged!(selectedLanguage);
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
                          isArabic ? "تطبيق اللغة" : "Apply Language",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _languageOption({
    required String title,
    required String subtitle,
    required String flag,
    required String value,
    required String selectedLanguage,
    required VoidCallback onTap,
  }) {
    final bool isSelected = value == selectedLanguage;

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
}

Widget _buildCounter(String number, String label) {
  return Column(
    children: [
      Text(
        number,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ],
  );
}

Widget _buildToggleItem({
  required IconData icon,
  required String label,
  required bool value,
  required bool loading,
  ValueChanged<bool>? onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withValues(alpha: 0.08),
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.teal,
                ),
              )
            : Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.teal,
                activeTrackColor: Colors.teal.withValues(alpha: 0.5),
              ),
      ],
    ),
  );
}

Widget _buildSettingsItem({
  required IconData icon,
  required String label,
  String? value,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 14),

          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),

          if (value != null)
            Text(value, style: const TextStyle(color: Colors.grey)),

          const SizedBox(width: 8),

          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    ),
  );
}
