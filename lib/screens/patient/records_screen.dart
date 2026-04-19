import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool showAppointments = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("No user logged in"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                "My Records",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Your appointments and consultations",
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              _buildTabs(user.uid),
              const SizedBox(height: 22),
              Expanded(
                child: showAppointments
                    ? _buildAppointmentsTab(user.uid)
                    : _buildConsultationsTab(user.uid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(String uid) {
    return StreamBuilder<List<int>>(
      stream: _combinedCounts(uid),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? [0, 0];
        final appointmentCount = counts[0];
        final consultationCount = counts[1];

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: _tabButton(
                  selected: showAppointments,
                  icon: Icons.calendar_today_outlined,
                  title: "Appointments",
                  badgeCount: appointmentCount,
                  onTap: () {
                    setState(() {
                      showAppointments = true;
                    });
                  },
                ),
              ),
              Expanded(
                child: _tabButton(
                  selected: !showAppointments,
                  icon: Icons.medical_information_outlined,
                  title: "Consultations",
                  badgeCount: consultationCount,
                  onTap: () {
                    setState(() {
                      showAppointments = false;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<List<int>> _combinedCounts(String uid) async* {
    await for (final appointmentsSnapshot in FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .snapshots()) {
      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: uid)
          .get();

      yield [
        appointmentsSnapshot.docs.length,
        consultationsSnapshot.docs.length,
      ];
    }
  }

  Widget _tabButton({
    required bool selected,
    required IconData icon,
    required String title,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF0F8B8D)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF0F8B8D)
                    : const Color(0xFF6B7280),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$badgeCount",
                  style: const TextStyle(
                    color: Color(0xFF0F8B8D),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F8B8D)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<QueryDocumentSnapshot> docs =
            List.from(snapshot.data?.docs ?? []);

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _buildEmptyAppointments();
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _AppointmentCard(
              appointmentId: docs[index].id,
              data: data,
            );
          },
        );
      },
    );
  }

  Widget _buildConsultationsTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F8B8D)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<QueryDocumentSnapshot> docs =
            List.from(snapshot.data?.docs ?? []);

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _buildEmptyConsultations();
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _ConsultationCard(
              consultationId: docs[index].id,
              data: data,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyAppointments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 62,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 18),
            const Text(
              "No appointments yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your booked appointments will appear here",
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConsultations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_information_outlined,
              size: 58,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 18),
            const Text(
              "No consultations yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your completed consultations will appear here",
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const _AppointmentCard({
    required this.appointmentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final DateTime bookedAt = createdAt?.toDate() ?? DateTime.now();

    final String hospital = (data['hospital'] ?? 'Dubai Hospital').toString();
    final String department =
        (data['department'] ?? 'General Medicine').toString();
    final String doctorName =
        (data['doctorName'] ?? 'Dr. Ahmed Al Rashid').toString();
    final String reason = (data['reason'] ?? 'Regular check up').toString();
    final String status = (data['status'] ?? 'scheduled').toString();
    final String date = (data['date'] ?? 'Thu, Feb 26').toString();
    final String time = (data['time'] ?? '04:00 PM').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hospital,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _statusBadge(_formatStatus(status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 18,
                color: Color(0xFF0F8B8D),
              ),
              const SizedBox(width: 6),
              Text(
                department,
                style: const TextStyle(
                  color: Color(0xFF0F8B8D),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _infoItem(
                icon: Icons.calendar_today_outlined,
                text: date,
              ),
              _infoItem(
                icon: Icons.access_time_outlined,
                text: time,
              ),
              _infoItem(
                icon: Icons.person_outline,
                text: doctorName,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "REASON",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Booked ${_formatBookedDate(bookedAt)}",
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(appointmentId)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Appointment removed")),
                  );
                },
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: 10,
            color: Color(0xFF0F8B8D),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F8B8D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'scheduled':
      default:
        return 'Scheduled';
    }
  }

  String _formatBookedDate(DateTime dt) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }
}

class _ConsultationCard extends StatelessWidget {
  final String consultationId;
  final Map<String, dynamic> data;

  const _ConsultationCard({
    required this.consultationId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final DateTime bookedAt = createdAt?.toDate() ?? DateTime.now();

    final String type = (data['consultationType'] ?? 'Video Call').toString();
    final String doctorName =
        (data['doctorName'] ?? 'Dr. Ahmed Al Rashid').toString();
    final String notes = (data['notes'] ?? 'General consultation').toString();
    final String status = (data['status'] ?? 'scheduled').toString();
    final String date = (data['date'] ?? 'Thu, Feb 26').toString();
    final String time = (data['time'] ?? '04:00 PM').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  "Online Consultation",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _statusBadge(_formatStatus(status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.video_call_outlined,
                size: 18,
                color: Color(0xFF0F8B8D),
              ),
              const SizedBox(width: 6),
              Text(
                type,
                style: const TextStyle(
                  color: Color(0xFF0F8B8D),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _infoItem(
                icon: Icons.calendar_today_outlined,
                text: date,
              ),
              _infoItem(
                icon: Icons.access_time_outlined,
                text: time,
              ),
              _infoItem(
                icon: Icons.person_outline,
                text: doctorName,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NOTES",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Booked ${_formatBookedDate(bookedAt)}",
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('consultations')
                      .doc(consultationId)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Consultation removed")),
                  );
                },
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: 10,
            color: Color(0xFF0F8B8D),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F8B8D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'scheduled':
      default:
        return 'Scheduled';
    }
  }

  String _formatBookedDate(DateTime dt) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }
}