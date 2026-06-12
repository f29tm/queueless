import 'package:flutter/material.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class DoctorNotificationsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorNotificationsScreen({super.key, required this.doctorId});

  @override
  State<DoctorNotificationsScreen> createState() =>
      _DoctorNotificationsScreenState();
}

class _DoctorNotificationsScreenState extends State<DoctorNotificationsScreen>
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

  // ─── Type styling ──────────────────────────────────────────────────────────
  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.appointmentCancelled:
      case NotificationType.consultationCancelled:
        return Icons.cancel_outlined;
      case NotificationType.triageOverride:
        return Icons.swap_vert_circle_outlined;
      case NotificationType.queueUpdate:
        return Icons.queue_outlined;
      case NotificationType.patientArrival:
        return Icons.people_alt_outlined;
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
      case NotificationType.patientArrival:
        return Colors.teal;
      case NotificationType.reminder:
        return const Color(0xFF2446B8);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─── Detail bottom sheet ───────────────────────────────────────────────────
  void _showDetails(BuildContext context, AppNotification notif) {
    _service.markAsRead(widget.doctorId, notif.id);
    final color = _colorFor(notif.type);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
                    notif.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notif.body,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (notif.metadata.containsKey('patientName')) ...[
              _metaRow(
                Icons.person_outline,
                'Patient',
                notif.metadata['patientName'],
              ),
              const SizedBox(height: 8),
            ],
            if (notif.metadata.containsKey('appointmentDate')) ...[
              _metaRow(
                Icons.calendar_today,
                'Date',
                notif.metadata['appointmentDate'],
              ),
              const SizedBox(height: 8),
            ],
            if (notif.metadata.containsKey('scheduledTime')) ...[
              _metaRow(
                Icons.access_time,
                'Time',
                notif.metadata['scheduledTime'],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              'Received ${_relativeTime(notif.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // ─── Notification tile ─────────────────────────────────────────────────────
  Widget _notifTile(AppNotification notif, BuildContext context) {
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
      onDismissed: (_) =>
          _service.deleteNotification(widget.doctorId, notif.id),
      child: GestureDetector(
        onTap: () => _showDetails(context, notif),
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
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(notif.createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
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
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return _emptyState('No notifications here');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) =>
          _notifTile(notifications[index], context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2446B8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _service.markAllAsRead(widget.doctorId),
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
          ],
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.notificationsStream(widget.doctorId),
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
                  ? _emptyState('No notifications yet')
                  : _buildList(all),
              unread.isEmpty
                  ? _emptyState("You're all caught up!")
                  : _buildList(unread),
            ],
          );
        },
      ),
    );
  }
}
