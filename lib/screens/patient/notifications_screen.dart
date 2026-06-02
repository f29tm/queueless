
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Type styling helpers ──────────────────────────────────────────────────
  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.appointmentCancelled:
      case NotificationType.consultationCancelled:
        return Icons.cancel_outlined;
      case NotificationType.triageOverride:
        return Icons.swap_vert_circle_outlined;
      case NotificationType.queueUpdate:
        return Icons.queue_outlined;
      case NotificationType.reminder:
        return Icons.alarm_outlined;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.appointmentCancelled:
      case NotificationType.consultationCancelled:
        return Colors.red;
      case NotificationType.triageOverride:
        return Colors.orange;
      case NotificationType.queueUpdate:
        return Colors.blue;
      case NotificationType.reminder:
        return Colors.teal;
    }
  }

  String _relativeTime(DateTime dt, bool isArabic) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return isArabic ? 'للتو' : 'Just now';
    if (diff.inMinutes < 60) {
      return isArabic ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isArabic ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return isArabic ? 'منذ ${diff.inDays} ي' : '${diff.inDays}d ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─── Long press menu ───────────────────────────────────────────────────────
  void _showLongPressMenu(
      BuildContext context, AppNotification notif, String patientId) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (!notif.isRead)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.mark_email_read_outlined,
                          color: Colors.green),
                    ),
                    title: Text(
                      isArabic ? 'تعليم كمقروء' : 'Mark as read',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _service.markAsRead(patientId, notif.id);
                    },
                  ),
                if (notif.isRead)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF3E0),
                      child: Icon(Icons.mark_email_unread_outlined,
                          color: Colors.orange),
                    ),
                    title: Text(
                      isArabic ? 'تعليم كغير مقروء' : 'Mark as unread',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FirestoreHelper.markAsUnread(patientId, notif.id);
                    },
                  ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: Text(
                    isArabic ? 'حذف' : 'Delete',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _service.deleteNotification(patientId, notif.id);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom sheet: notification details ───────────────────────────────────
  void _showDetails(
      BuildContext context, AppNotification notif, String patientId) {
    _service.markAsRead(patientId, notif.id);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final color = _colorFor(notif.type);
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(_iconFor(notif.type), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notif.localizedTitle(isArabic),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(notif.localizedBody(isArabic),
                    style:
                        const TextStyle(fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 16),
                if (notif.metadata.containsKey('reason')) ...[
                  _metaRow(Icons.info_outline,
                      isArabic ? 'السبب' : 'Reason',
                      notif.metadata['reason']),
                  const SizedBox(height: 8),
                ],
                if (notif.metadata.containsKey('doctorName')) ...[
                  _metaRow(Icons.person_outline,
                      isArabic ? 'الطبيب' : 'Doctor',
                      '${notif.metadata['doctorName']}'),
                  const SizedBox(height: 8),
                ],
                if (notif.metadata.containsKey('nurseName')) ...[
                  _metaRow(Icons.person_outline,
                      isArabic ? 'الممرضة' : 'Nurse',
                      notif.metadata['nurseName']),
                  const SizedBox(height: 8),
                ],
                if (notif.metadata.containsKey('appointmentDate')) ...[
                  _metaRow(Icons.calendar_today,
                      isArabic ? 'التاريخ' : 'Date',
                      notif.metadata['appointmentDate']),
                  const SizedBox(height: 8),
                ],
                if (notif.metadata.containsKey('scheduledTime')) ...[
                  _metaRow(Icons.access_time,
                      isArabic ? 'الوقت' : 'Time',
                      notif.metadata['scheduledTime']),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'تم الاستلام ${_relativeTime(notif.createdAt, true)}'
                      : 'Received ${_relativeTime(notif.createdAt, false)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ─── Notification tile ─────────────────────────────────────────────────────
  Widget _notifTile(
      AppNotification notif, String patientId, BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final color = _colorFor(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _service.deleteNotification(patientId, notif.id),
      child: GestureDetector(
        onTap: () => _showDetails(context, notif, patientId),
        onLongPress: () => _showLongPressMenu(context, notif, patientId),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: notif.isRead
                ? null
                : Border.all(color: color.withValues(alpha: 0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            textDirection:
                isArabic ? TextDirection.rtl : TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(_iconFor(notif.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.localizedTitle(isArabic),
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(notif.createdAt, isArabic),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.localizedBody(isArabic),
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  // ─── List view ─────────────────────────────────────────────────────────────
  Widget _buildList(List<AppNotification> notifications, String patientId) {
    if (notifications.isEmpty) {
      final isArabic =
          Localizations.localeOf(context).languageCode == 'ar';
      return _emptyState(
          isArabic ? 'لا توجد إشعارات هنا' : 'No notifications here');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) =>
          _notifTile(notifications[index], patientId, context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientId =
        Provider.of<AuthProvider>(context, listen: false).userId ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: Text(
            isArabic ? 'الإشعارات' : 'Notifications',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: () => _service.markAllAsRead(patientId),
              child: Text(
                isArabic ? 'تعليم الكل كمقروء' : 'Mark all read',
                style: const TextStyle(color: Colors.teal),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(text: isArabic ? 'الكل' : 'All'),
              Tab(text: isArabic ? 'غير المقروء' : 'Unread'),
            ],
          ),
        ),
        body: StreamBuilder<List<AppNotification>>(
          stream: _service.notificationsStream(patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = snapshot.data ?? [];
            final unread = all.where((n) => !n.isRead).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                all.isEmpty
                    ? _emptyState(
                        isArabic ? 'لا توجد إشعارات بعد' : 'No notifications yet')
                    : _buildList(all, patientId),

                unread.isEmpty
                    ? _emptyState(isArabic
                        ? 'تمت قراءة جميع الإشعارات!'
                        : 'You\'re all caught up!')
                    : _buildList(unread, patientId),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Helper for mark as unread (not in NotificationService) ───────────────────
class FirestoreHelper {
  static Future<void> markAsUnread(
      String patientId, String notificationId) async {
    await FirestoreHelper._ref(patientId)
        .doc(notificationId)
        .update({'isRead': false});
  }

  static CollectionReference _ref(String patientId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('notifications');
}
