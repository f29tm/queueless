import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int selectedIndex = 0;

  void goToProfile() {
    setState(() {
      selectedIndex = 3;
    });
  }

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
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Appointments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "Patients",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: "Consults",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// ===================== APPOINTMENTS PAGE =====================

class DoctorAppointmentsPage extends StatelessWidget {
  final VoidCallback onProfileTap;

  const DoctorAppointmentsPage({
    super.key,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;

    if (doctorUid == null) {
      return const Scaffold(
        body: Center(child: Text("No doctor logged in")),
      );
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
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return _blueHeader(
                "Appointments",
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
                    child: Text(
                      "No appointments found",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final appointmentDoc = docs[index];
                    final data = appointmentDoc.data() as Map<String, dynamic>;

                    return AppointmentCard(
                      docId: appointmentDoc.id,
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

  const DoctorPatientsPage({
    super.key,
    required this.onProfileTap,
  });

  @override
  State<DoctorPatientsPage> createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  Stream<QuerySnapshot> get _stream =>
      FirebaseFirestore.instance
          .collection('queue')
          .where('status', isEqualTo: 'waiting_doctor')
          .orderBy('finalPriorityNumber')
          .orderBy('triageCompletedAt')
          .snapshots();

  // ── helpers ────────────────────────────────────────────────

  String _effectiveLevel(Map<String, dynamic> data) =>
      (data['finalTriageLevel'] as String?) ??
      (data['triageLevel'] as String?) ??
      'LOW';

  Color _levelColor(String level) {
    switch (level) {
      case 'EMERGENCY':
        return Colors.red;
      case 'MODERATE':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'EMERGENCY':
        return 'Emergency';
      case 'MODERATE':
        return 'Urgent';
      default:
        return 'Non-Urgent';
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          final header = _blueHeader(
            "Patient Queue",
            subtitle: "Sorted by severity",
            onProfileTap: widget.onProfileTap,
          );

          if (snapshot.hasError) {
            return Column(children: [
              header,
              const Expanded(
                child: Center(
                  child: Text(
                    "Error loading queue",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            ]);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(children: [
              header,
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF2446B8)),
                ),
              ),
            ]);
          }

          final docs = snapshot.data!.docs;

          int emergencyCount = 0;
          int urgentCount = 0;
          for (final doc in docs) {
            final level =
                _effectiveLevel(doc.data() as Map<String, dynamic>);
            if (level == 'EMERGENCY') emergencyCount++;
            if (level == 'MODERATE') urgentCount++;
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
                    child: Text(
                      "No patients waiting for doctor",
                      style:
                          TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data()
                          as Map<String, dynamic>;
                      final level = _effectiveLevel(data);
                      final borderColor = _levelColor(level);
                      final patientName =
                          data['patientName'] as String? ?? 'Unknown';
                      final completedAt =
                          data['triageCompletedAt'] as Timestamp?;
                      final symptoms = (data['symptoms'] as List?)
                              ?.map((s) => s.toString())
                              .join(', ') ??
                          '';
                      final nurseOverride =
                          data['nurseOverride'] as bool? ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border(
                            left: BorderSide(
                                color: borderColor, width: 5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Level chip + override chip + time
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _levelLabel(level),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (nurseOverride) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                              Colors.amber.shade300),
                                    ),
                                    child: Text(
                                      "Nurse overridden",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _timeAgo(completedAt),
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              patientName,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (symptoms.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                symptoms,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
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

  const DoctorConsultsPage({
    super.key,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;

    if (doctorUid == null) {
      return const Scaffold(
        body: Center(child: Text("No doctor logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          _blueHeader(
            "Consults",
            onProfileTap: onProfileTap,
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
                    child: Text(
                      "No active consults",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final consultDoc = docs[index];
                    final data = consultDoc.data() as Map<String, dynamic>;

                    return ConsultationCard(
                      docId: consultDoc.id,
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
        body: Center(child: Text("No doctor logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Doctor profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final name = data["name"] ?? "Doctor";
          final specialty = data["specialty"] ?? "Doctor";
          final hospital = data["hospital"] ?? "Not available";
          final department = data["department"] ?? "Not available";
          final email = data["email"] ?? "Not available";
          final status = data["status"] ?? "active";
          final staffId = data["staffId"] ?? "Not available";

          final statusText =
              status.toString().toLowerCase() == "active" ? "Available" : status.toString();

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
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      specialty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "● $statusText",
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),

              _sectionCard(
                title: "Professional Info",
                children: [
                  InfoRow(
                    icon: Icons.local_hospital,
                    label: "Hospital",
                    value: hospital,
                  ),
                  InfoRow(
                    icon: Icons.medical_services,
                    label: "Department",
                    value: department,
                  ),
                  InfoRow(
                    icon: Icons.badge,
                    label: "Staff ID",
                    value: staffId,
                  ),
                  const InfoRow(
                    icon: Icons.videocam,
                    label: "Consult Types",
                    value: "video, phone",
                  ),
                ],
              ),

              _sectionCard(
                title: "Account",
                children: [
                  InfoRow(
                    icon: Icons.person_outline,
                    label: "Username",
                    value: staffId,
                  ),
                  InfoRow(
                    icon: Icons.email_outlined,
                    label: "Email",
                    value: email,
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      "Sign Out",
                      style: TextStyle(color: Colors.red),
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
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ===================== CARDS =====================

class AppointmentCard extends StatelessWidget {
  final String docId;
  final String patientId;
  final String date;
  final String time;
  final String department;
  final String hospital;
  final String reason;
  final String status;

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

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection("appointments").doc(docId).update({
      "status": newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(patientId).get(),
      builder: (context, patientSnapshot) {
        String patientName = "Patient";
        String patientEmail = "";

        if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
          final patientData = patientSnapshot.data!.data() as Map<String, dynamic>;
          patientName = patientData["name"] ?? "Patient";
          patientEmail = patientData["email"] ?? "";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$date   $time",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2446B8),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        Text(patientEmail, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus("completed"),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text("Complete", style: TextStyle(color: Colors.green)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9F8DF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus("cancelled"),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text("Cancel", style: TextStyle(color: Colors.red)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBDADD),
                      ),
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

class ConsultationCard extends StatelessWidget {
  final String docId;
  final String patientId;
  final String date;
  final String time;
  final String type;
  final String notes;
  final String status;

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

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection("consultations").doc(docId).update({
      "status": newStatus,
    });
  }

  IconData _typeIcon() {
    if (type.toLowerCase().contains("video")) return Icons.videocam;
    if (type.toLowerCase().contains("phone")) return Icons.call;
    return Icons.chat;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(patientId).get(),
      builder: (context, patientSnapshot) {
        String patientName = "Patient";
        String patientEmail = "";

        if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
          final patientData = patientSnapshot.data!.data() as Map<String, dynamic>;
          patientName = patientData["name"] ?? "Patient";
          patientEmail = patientData["email"] ?? "";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$date   $time",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2446B8),
                    child: Icon(_typeIcon(), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        Text(patientEmail, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                type,
                style: const TextStyle(
                  color: Color(0xFF2446B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (notes.isNotEmpty) Text(notes, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus("completed"),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text("Complete", style: TextStyle(color: Colors.green)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9F8DF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus("cancelled"),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text("Cancel", style: TextStyle(color: Colors.red)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBDADD),
                      ),
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

Widget _blueHeader(
  String title, {
  String? subtitle,
  String? rightText,
  VoidCallback? onProfileTap,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 60, left: 26, right: 20, bottom: 25),
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
                    fontWeight: FontWeight.bold,
                  )),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),

        if (rightText != null)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(rightText, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),

        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.person_outline, color: Colors.white, size: 30),
        ),
      ],
    ),
  );
}

Widget _sectionCard({
  required String title,
  required List<Widget> children,
}) {
  return Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

Widget _statusBadge(String status) {
  Color bgColor;
  Color textColor;

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
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(status, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF2446B8)),
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 17, color: Colors.black)),
    );
  }
}

class StatBox extends StatelessWidget {
  final String number;
  final String label;
  final Color color;

  const StatBox({
    super.key,
    required this.number,
    required this.label,
    required this.color,
  });

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
                style: TextStyle(fontSize: 28, color: color, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
