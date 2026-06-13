
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import '../../services/encryption_service.dart';
import '../../services/notification_service.dart';
import '../../utils/triage_levels.dart';
import 'doctor_notifications_screen.dart';
import 'doctor_patient_detail_screen.dart';

String _todayLabel() => DateFormat('EEE, MMM d').format(DateTime.now());

// ── Cancel dialog with dropdown reasons + optional notes ─────────────────────
Future<String?> _showDoctorCancelConfirmation(
    BuildContext context, String itemType) async {
  final List<String> presetReasons = [
    'Doctor on leave',
    'Emergency case',
    'Schedule conflict',
    'Please reschedule',
    'Technical issue',
    'Other',
  ];

  String selectedReason = presetReasons.first;
  final notesController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text('Cancel $itemType'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The patient will be notified with the reason you provide.',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Reason *',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: presetReasons
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedReason = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Additional notes (optional)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Please call us to reschedule',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8B8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true) {
    final notes = notesController.text.trim();
    return notes.isEmpty ? selectedReason : '$selectedReason — $notes';
  }
  return null;
}

// ── Complete dialog ───────────────────────────────────────────────────────────
Future<bool> _showDoctorCompleteConfirmation(
    BuildContext context, String itemType) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text('Complete $itemType'),
        content: Text(
          'Are you sure you want to mark this $itemType as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F8B8D),
            ),
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

int _countTodayItems(QuerySnapshot? snapshot) {
  if (snapshot == null) return 0;
  final today = _todayLabel();
  return snapshot.docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] as String?)?.toLowerCase() ?? '';
    return status != 'cancelled' && (data['date'] as String?) == today;
  }).length;
}

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int selectedIndex = 0;

  void goToProfile() => setState(() => selectedIndex = 3);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DoctorAppointmentsPage(onProfileTap: goToProfile),
      DoctorPatientsPage(onProfileTap: goToProfile),
      DoctorConsultsPage(onProfileTap: goToProfile),
      const DoctorProfilePage(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2446B8),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: "Appointments"),
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: "Patients"),
          BottomNavigationBarItem(
              icon: Icon(Icons.videocam), label: "Consults"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ===================== APPOINTMENTS PAGE =====================

class DoctorAppointmentsPage extends StatelessWidget {
  final VoidCallback onProfileTap;
  const DoctorAppointmentsPage({super.key, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;
    if (doctorUid == null) {
      return const Scaffold(
          body: Center(child: Text("No doctor logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("appointments")
                .where("doctorUid", isEqualTo: doctorUid)
                .snapshots(),
            builder: (context, snapshot) {
              final count = _countTodayItems(snapshot.data);
              return _blueHeader(
                context,
                "Appointments",
                doctorUid: doctorUid,
                rightText: "$count today",
                onProfileTap: onProfileTap,
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("appointments")
                  .where("doctorUid", isEqualTo: doctorUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No appointments found",
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return AppointmentCard(
                      docId: doc.id,
                      patientId: data["patientId"] ?? "",
                      date: data["date"] ?? "",
                      time: data["time"] ?? "",
                      department: data["department"] ?? "",
                      hospital: data["hospital"] ?? "",
                      reason: data["reason"] ?? "",
                      status: data["status"] ?? "scheduled",
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== PATIENTS PAGE =====================

class DoctorPatientsPage extends StatefulWidget {
  final VoidCallback onProfileTap;
  const DoctorPatientsPage({super.key, required this.onProfileTap});

  @override
  State<DoctorPatientsPage> createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('queue')
      .where('status', isEqualTo: 'waiting_doctor')
      .snapshots();

  String _effectiveLevel(Map<String, dynamic> data) =>
      (data['finalTriageLevel'] as String?) ??
      (data['triageLevel'] as String?) ??
      'LOW';

  Color _levelColor(String level) => TriageLevels.color(level);

  String _levelLabel(String level) => TriageLevels.labelEn(level);

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          final header = _blueHeader(
            context,
            "Patient Queue",
            doctorUid: doctorUid,
            subtitle: "Sorted by severity",
            onProfileTap: widget.onProfileTap,
          );

          if (snapshot.hasError) {
            return Column(children: [
              header,
              const Expanded(
                  child: Center(
                      child: Text("Error loading queue",
                          style: TextStyle(
                              color: Colors.grey, fontSize: 16)))),
            ]);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(children: [
              header,
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2446B8)))),
            ]);
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final da = a.data() as Map<String, dynamic>;
              final db = b.data() as Map<String, dynamic>;
              final pa = (da['finalPriorityNumber'] as num?)?.toInt() ?? 3;
              final pb = (db['finalPriorityNumber'] as num?)?.toInt() ?? 3;
              if (pa != pb) return pa.compareTo(pb);
              final ta = (da['triageCompletedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final tb = (db['triageCompletedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              return ta.compareTo(tb);
            });
          int emergencyCount = 0, urgentCount = 0;
          for (final doc in docs) {
            final level =
                _effectiveLevel(doc.data() as Map<String, dynamic>);
            if (level == TriageLevels.emergency) emergencyCount++;
            if (level == TriageLevels.moderate) urgentCount++;
          }

          return Column(
            children: [
              header,
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    StatBox(
                        number: '$emergencyCount',
                        label: "Emergency",
                        color: Colors.red),
                    const SizedBox(width: 12),
                    StatBox(
                        number: '$urgentCount',
                        label: "Urgent",
                        color: Colors.orange),
                    const SizedBox(width: 12),
                    StatBox(
                        number: '${docs.length}',
                        label: "Active",
                        color: const Color(0xFF2446B8)),
                  ],
                ),
              ),
              if (docs.isEmpty)
                const Expanded(
                    child: Center(
                        child: Text("No patients waiting for doctor",
                            style: TextStyle(
                                color: Colors.grey, fontSize: 16))))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final level = _effectiveLevel(data);
                      final borderColor = _levelColor(level);
                      final patientName =
                          data['patientName'] as String? ?? 'Unknown';
                      final patientId =
                          data['patientId'] as String? ?? '';
                      final queueDocId = docs[index].id;
                      final completedAt =
                          data['triageCompletedAt'] as Timestamp?;
                      final rawSymptoms = data['symptoms'];
                      final symptomList = rawSymptoms is List
                          ? rawSymptoms.map((s) => s.toString()).toList()
                          : <String>[];
                      final symptoms = symptomList.join(', ');
                      final nurseOverride =
                          data['nurseOverride'] as bool? ?? false;

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorPatientDetailScreen(
                              queueDocId: queueDocId,
                              patientId: patientId,
                              patientName: patientName,
                              triageLevel: level,
                              symptoms: symptomList,
                            ),
                          ),
                        ),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border(
                              left: BorderSide(
                                  color: borderColor, width: 5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Text(_levelLabel(level),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (nurseOverride) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.amber.shade300),
                                    ),
                                    child: Text("Nurse overridden",
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                                const Spacer(),
                                Text(_timeAgo(completedAt),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(patientName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            if (symptoms.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(symptoms,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ===================== CONSULTS PAGE =====================

class DoctorConsultsPage extends StatelessWidget {
  final VoidCallback onProfileTap;
  const DoctorConsultsPage({super.key, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;
    if (doctorUid == null) {
      return const Scaffold(
          body: Center(child: Text("No doctor logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("consultations")
                .where("doctorUid", isEqualTo: doctorUid)
                .snapshots(),
            builder: (context, snapshot) {
              final count = _countTodayItems(snapshot.data);
              return _blueHeader(
                context,
                "Consults",
                doctorUid: doctorUid,
                rightText: "$count today",
                onProfileTap: onProfileTap,
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("consultations")
                  .where("doctorUid", isEqualTo: doctorUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No active consults",
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ConsultationCard(
                      docId: doc.id,
                      patientId: data["patientId"] ?? "",
                      date: data["date"] ?? "",
                      time: data["time"] ?? "",
                      type: data["consultationType"] ?? "",
                      notes: data["notes"] ?? "",
                      status: data["status"] ?? "scheduled",
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== DOCTOR PROFILE PAGE =====================

class DoctorProfilePage extends StatelessWidget {
  const DoctorProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text("No doctor logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Doctor profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name      = data["name"]       ?? "Doctor";
          final specialty = data["specialty"]  ?? "Doctor";
          final hospital  = data["hospital"]   ?? "Not available";
          final department= data["department"] ?? "Not available";
          final email     = data["email"]      ?? "Not available";
          final status    = data["status"]     ?? "active";
          final staffId   = data["staffId"]    ?? "Not available";
          final statusText = status.toString().toLowerCase() == "active"
              ? "Available"
              : status.toString();

          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 55, bottom: 35),
                color: const Color(0xFF2446B8),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 55,
                      backgroundColor: Color(0xFF5B73D6),
                      child: Icon(Icons.person,
                          size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                    Text(specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text("● $statusText",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
              _sectionCard(title: "Professional Info", children: [
                InfoRow(
                    icon: Icons.local_hospital,
                    label: "Hospital",
                    value: hospital),
                InfoRow(
                    icon: Icons.medical_services,
                    label: "Department",
                    value: department),
                InfoRow(
                    icon: Icons.badge, label: "Staff ID", value: staffId),
                const InfoRow(
                    icon: Icons.videocam,
                    label: "Consult Types",
                    value: "video, phone"),
              ]),
              _sectionCard(title: "Account", children: [
                InfoRow(
                    icon: Icons.person_outline,
                    label: "Username",
                    value: staffId),
                InfoRow(
                    icon: Icons.email_outlined,
                    label: "Email",
                    value: email),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text("Sign Out",
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ===================== APPOINTMENT CARD =====================

class AppointmentCard extends StatelessWidget {
  final String docId, patientId, date, time, department, hospital, reason, status;

  const AppointmentCard({
    super.key,
    required this.docId,
    required this.patientId,
    required this.date,
    required this.time,
    required this.department,
    required this.hospital,
    required this.reason,
    required this.status,
  });

  Future<void> _updateStatus(BuildContext context, String newStatus,
      {String cancelReason = 'Doctor on leave'}) async {
    await FirebaseFirestore.instance
        .collection("appointments")
        .doc(docId)
        .update({"status": newStatus});

    if (newStatus == "cancelled" && patientId.isNotEmpty) {
      final doctorSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final doctorName =
          (doctorSnapshot.data()?["name"] as String?) ?? "Your doctor";

      await NotificationService().notifyAppointmentCancelled(
        patientId: patientId,
        appointmentId: docId,
        doctorName: doctorName,
        appointmentDate: "$date at $time",
        reason: cancelReason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .get(),
      builder: (context, snap) {
        final patientData = snap.data?.data() as Map<String, dynamic>?;
        final patientName = patientData?["name"] ?? "Patient";
        final patientEmail = patientData?["email"] ?? "";

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$date   $time",
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                      backgroundColor: Color(0xFF2446B8),
                      child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                        Text(patientEmail,
                            style:
                                const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (status.toLowerCase() == 'scheduled')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok =
                              await _showDoctorCompleteConfirmation(
                                  context, 'appointment');
                          if (ok && context.mounted) {
                            await _updateStatus(context, "completed");
                          }
                        },
                        icon: const Icon(Icons.check_circle,
                            color: Colors.green),
                        label: const Text("Complete",
                            style: TextStyle(color: Colors.green)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9F8DF)),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (status.toLowerCase() == 'scheduled')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final r =
                              await _showDoctorCancelConfirmation(
                                  context, 'appointment');
                          if (r != null && context.mounted) {
                            await _updateStatus(context, "cancelled",
                                cancelReason: r);
                          }
                        },
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text("Cancel",
                            style: TextStyle(color: Colors.red)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBDADD)),
                      ),
                    ),
                ],
              ),
              if (status.toLowerCase() != 'cancelled') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showPrescriptionForm(
                      context,
                      patientId: patientId,
                      patientName: patientName,
                    ),
                    icon: const Icon(Icons.medication,
                        color: Colors.teal, size: 18),
                    label: const Text('Write Prescription',
                        style: TextStyle(color: Colors.teal)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ===================== CONSULTATION CARD =====================

class ConsultationCard extends StatelessWidget {
  final String docId, patientId, date, time, type, notes, status;

  const ConsultationCard({
    super.key,
    required this.docId,
    required this.patientId,
    required this.date,
    required this.time,
    required this.type,
    required this.notes,
    required this.status,
  });

  Future<void> _updateStatus(BuildContext context, String newStatus,
      {String cancelReason = 'Doctor on leave'}) async {
    await FirebaseFirestore.instance
        .collection("consultations")
        .doc(docId)
        .update({"status": newStatus});

    if (newStatus == "cancelled" && patientId.isNotEmpty) {
      final doctorSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final doctorName =
          (doctorSnapshot.data()?["name"] as String?) ?? "Your doctor";

      await NotificationService().notifyConsultationCancelled(
        patientId: patientId,
        consultationId: docId,
        doctorName: doctorName,
        scheduledTime: "$date at $time",
        reason: cancelReason,
        consultationType: type,
      );
    }
  }

  IconData _typeIcon() {
    if (type.toLowerCase().contains("video")) return Icons.videocam;
    if (type.toLowerCase().contains("phone")) return Icons.call;
    return Icons.chat;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .get(),
      builder: (context, snap) {
        final patientData = snap.data?.data() as Map<String, dynamic>?;
        final patientName = patientData?["name"] ?? "Patient";
        final patientEmail = patientData?["email"] ?? "";

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$date   $time",
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                      backgroundColor: const Color(0xFF2446B8),
                      child: Icon(_typeIcon(), color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                        Text(patientEmail,
                            style:
                                const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Text(type,
                  style: const TextStyle(
                      color: Color(0xFF2446B8),
                      fontWeight: FontWeight.bold)),
              if (notes.isNotEmpty)
                FutureBuilder<String>(
                  future: (':'.allMatches(notes).length == 2)
                      ? EncryptionService.getDecryptedData(
                          collection: 'consultations',
                          docId: docId,
                          fields: ['notes'],
                        ).then((d) => (d['notes'] as String?) ?? notes)
                      : Future.value(notes),
                  builder: (_, snap) => Text(
                    snap.data ?? notes,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (status.toLowerCase() == 'scheduled')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok =
                              await _showDoctorCompleteConfirmation(
                                  context, 'consultation');
                          if (ok && context.mounted) {
                            await _updateStatus(context, "completed");
                          }
                        },
                        icon: const Icon(Icons.check_circle,
                            color: Colors.green),
                        label: const Text("Complete",
                            style: TextStyle(color: Colors.green)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9F8DF)),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (status.toLowerCase() == 'scheduled')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final r =
                              await _showDoctorCancelConfirmation(
                                  context, 'consultation');
                          if (r != null && context.mounted) {
                            await _updateStatus(context, "cancelled",
                                cancelReason: r);
                          }
                        },
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text("Cancel",
                            style: TextStyle(color: Colors.red)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBDADD)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================== SHARED WIDGETS =====================

// ── Blue header now includes bell icon with unread badge ──────────────────────
Widget _blueHeader(
  BuildContext context,
  String title, {
  required String doctorUid,
  String? subtitle,
  String? rightText,
  VoidCallback? onProfileTap,
}) {
  return Container(
    width: double.infinity,
    padding:
        const EdgeInsets.only(top: 60, left: 26, right: 20, bottom: 25),
    color: const Color(0xFF2446B8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        if (rightText != null)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(rightText,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16)),
          ),
        // ── Bell icon with unread badge ──────────────────────────────
        StreamBuilder<int>(
          stream:
              NotificationService().unreadCountStream(doctorUid),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorNotificationsScreen(
                            doctorId: doctorUid),
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
                          shape: BoxShape.circle),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.person_outline,
              color: Colors.white, size: 30),
        ),
      ],
    ),
  );
}

Widget _sectionCard(
    {required String title, required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

Widget _statusBadge(String status) {
  Color bgColor, textColor;
  switch (status.toLowerCase()) {
    case "completed":
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      break;
    case "cancelled":
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      break;
    default:
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(16)),
    child: Text(status,
        style:
            TextStyle(color: textColor, fontWeight: FontWeight.bold)),
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF2446B8)),
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 17, color: Colors.black)),
    );
  }
}

class StatBox extends StatelessWidget {
  final String number, label;
  final Color color;
  const StatBox(
      {super.key,
      required this.number,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(number,
                style: TextStyle(
                    fontSize: 28,
                    color: color,
                    fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
