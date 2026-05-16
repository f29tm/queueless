import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../staff/staff_login_screen.dart';

class NurseDashboardScreen extends StatefulWidget {
  const NurseDashboardScreen({super.key});

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      NurseQueuePage(),
      NurseProfilePage(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF2446B8),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: "Queue",
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

// ===================== NURSE QUEUE PAGE =====================

class NurseQueuePage extends StatefulWidget {
  const NurseQueuePage({super.key});

  @override
  State<NurseQueuePage> createState() => _NurseQueuePageState();
}

class _NurseQueuePageState extends State<NurseQueuePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _nurseQueueStream() {
    return _firestore
        .collection('queue')
        .where('queueType', isEqualTo: 'nurse')
        .where('status', isEqualTo: 'waiting_nurse')
        .orderBy('priorityNumber')
        .orderBy('createdAt')
        .snapshots();
  }

  int _priorityNumber(String priority) {
    if (priority == "EMERGENCY") return 1;
    if (priority == "MODERATE") return 2;
    return 3;
  }

  Color _priorityColor(String priority) {
    if (priority == "EMERGENCY") return Colors.red;
    if (priority == "MODERATE") return Colors.orange;
    return Colors.green;
  }

  Future<void> _openVitalsDialog(DocumentSnapshot patientDoc) async {
    final temperatureController = TextEditingController();
    final bloodPressureController = TextEditingController();
    final heartRateController = TextEditingController();
    final oxygenController = TextEditingController();

    final data = patientDoc.data() as Map<String, dynamic>;
    String selectedPriority = data['triageLevel'] ?? 'LOW';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Record Patient Vitals"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: temperatureController,
                  decoration: const InputDecoration(
                    labelText: "Temperature",
                    hintText: "Example: 37.5",
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: bloodPressureController,
                  decoration: const InputDecoration(
                    labelText: "Blood Pressure",
                    hintText: "Example: 120/80",
                  ),
                ),
                TextField(
                  controller: heartRateController,
                  decoration: const InputDecoration(
                    labelText: "Heart Rate",
                    hintText: "Example: 90",
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: oxygenController,
                  decoration: const InputDecoration(
                    labelText: "Oxygen Level",
                    hintText: "Example: 98",
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: "Final Triage Priority",
                  ),
                  items: const [
                    DropdownMenuItem(value: "LOW", child: Text("LOW")),
                    DropdownMenuItem(value: "MODERATE", child: Text("MODERATE")),
                    DropdownMenuItem(value: "EMERGENCY", child: Text("EMERGENCY")),
                  ],
                  onChanged: (value) {
                    selectedPriority = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _finishNurseTriage(
                  patientDoc: patientDoc,
                  temperature: temperatureController.text.trim(),
                  bloodPressure: bloodPressureController.text.trim(),
                  heartRate: heartRateController.text.trim(),
                  oxygenLevel: oxygenController.text.trim(),
                  finalPriority: selectedPriority,
                );

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Finish Triage"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishNurseTriage({
    required DocumentSnapshot patientDoc,
    required String temperature,
    required String bloodPressure,
    required String heartRate,
    required String oxygenLevel,
    required String finalPriority,
  }) async {
    final data = patientDoc.data() as Map<String, dynamic>;

    final oldPriority = data['triageLevel'] ?? "LOW";
    final patientId = data['patientId'];
    final patientName = data['patientName'] ?? "Unknown Patient";

    final batch = _firestore.batch();

    final queueRef = _firestore.collection('queue').doc(patientDoc.id);

    batch.update(queueRef, {
      'vitalSigns': {
        'temperature': temperature,
        'bloodPressure': bloodPressure,
        'heartRate': heartRate,
        'oxygenLevel': oxygenLevel,
      },
      'triageLevel': finalPriority,
      'priorityNumber': _priorityNumber(finalPriority),
      'status': 'waiting_doctor',
      'queueType': 'doctor',
      'nurseChecked': true,
      'nurseCheckedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final recordRef = _firestore.collection('medical_records').doc();

    batch.set(recordRef, {
      'patientId': patientId,
      'patientName': patientName,
      'triageLevel': finalPriority,
      'oldTriageLevel': oldPriority,
      'vitalSigns': {
        'temperature': temperature,
        'bloodPressure': bloodPressure,
        'heartRate': heartRate,
        'oxygenLevel': oxygenLevel,
      },
      'type': 'nurse_triage',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (oldPriority != finalPriority) {
      final notificationRef = _firestore.collection('notifications').doc();

      batch.set(notificationRef, {
        'patientId': patientId,
        'title': 'Triage Updated',
        'message': 'Your triage priority was updated to $finalPriority.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Triage finished. Patient moved to doctor queue."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
            color: const Color(0xFF2446B8),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nurse Dashboard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Validate patient triage and record vital signs",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _nurseQueueStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patients = snapshot.data?.docs ?? [];

                if (patients.isEmpty) {
                  return const Center(
                    child: Text(
                      "No patients in nurse queue",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                final high = patients.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data["triageLevel"] == "EMERGENCY";
                }).length;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        _statBox("${patients.length}", "Waiting", const Color(0xFF2446B8)),
                        const SizedBox(width: 12),
                        _statBox("$high", "High Priority", Colors.red),
                      ],
                    ),
                    const SizedBox(height: 20),

                    ...patients.map((patient) {
                      final data = patient.data() as Map<String, dynamic>;

                      final patientName = data['patientName'] ?? 'Unknown Patient';
                      final triageLevel = data['triageLevel'] ?? 'LOW';
                      final symptoms = data['symptoms'] ?? [];
                      final description = data['description'] ?? 'No description';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border(
                            left: BorderSide(
                              color: _priorityColor(triageLevel),
                              width: 5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF2446B8),
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    patientName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _priorityBadge(triageLevel),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Text(
                              "Symptoms: ${symptoms.toString()}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Description: $description",
                              style: const TextStyle(color: Colors.grey),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openVitalsDialog(patient),
                                icon: const Icon(Icons.monitor_heart),
                                label: const Text("Record Vitals & Finish Triage"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2446B8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String number, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 28,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _priorityColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: _priorityColor(priority),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ===================== NURSE PROFILE PAGE =====================

class NurseProfilePage extends StatelessWidget {
  const NurseProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("No nurse logged in")),
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
            return const Center(child: Text("Nurse profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final name = data["name"] ?? "Nurse";
          final hospital = data["hospital"] ?? "Not available";
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
                      child: Icon(Icons.local_hospital, size: 58, color: Colors.white),
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
                    const Text(
                      "Triage Nurse",
                      style: TextStyle(color: Colors.white, fontSize: 18),
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
                  _infoRow(
                    icon: Icons.local_hospital,
                    label: "Hospital",
                    value: hospital,
                  ),
                  _infoRow(
                    icon: Icons.assignment_ind,
                    label: "Role",
                    value: "Nurse - Triage Validation",
                  ),
                  _infoRow(
                    icon: Icons.badge,
                    label: "Staff ID",
                    value: staffId,
                  ),
                  _infoRow(
                    icon: Icons.monitor_heart,
                    label: "Main Task",
                    value: "Record vitals and validate AI triage",
                  ),
                ],
              ),

              _sectionCard(
                title: "Account",
                children: [
                  _infoRow(
                    icon: Icons.person_outline,
                    label: "Username",
                    value: staffId,
                  ),
                  _infoRow(
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

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF2446B8)),
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 17, color: Colors.black)),
    );
  }
}