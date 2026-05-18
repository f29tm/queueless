import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/triage_service.dart';
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

  Color _priorityColor(String priority) {
    if (priority == "EMERGENCY") return Colors.red;
    if (priority == "MODERATE") return Colors.orange;
    if (priority == "PENDING") return Colors.grey;
    return Colors.green;
  }

  Future<void> _openVitalsDialog(DocumentSnapshot doc) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VitalsSheet(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
                top: 60, left: 24, right: 24, bottom: 24),
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
                        _statBox("${patients.length}", "Waiting",
                            const Color(0xFF2446B8)),
                        const SizedBox(width: 12),
                        _statBox("$high", "High Priority", Colors.red),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...patients.map((patient) {
                      final data = patient.data() as Map<String, dynamic>;
                      final patientName =
                          data['patientName'] ?? 'Unknown Patient';
                      final triageLevel = data['triageLevel'] ?? 'LOW';
                      final symptoms = data['symptoms'] ?? [];
                      final description =
                          data['description'] ?? 'No description';
                      final isManual = data['noAITriage'] == true;

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
                                  child:
                                      Icon(Icons.person, color: Colors.white),
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
                                _priorityBadge(
                                    triageLevel, isManual),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (!isManual) ...[
                              Text(
                                "Symptoms: ${symptoms.toString()}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Description: $description",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ] else
                              const Text(
                                "Manual check-in — no prior symptom assessment",
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openVitalsDialog(patient),
                                icon: const Icon(Icons.monitor_heart),
                                label: const Text(
                                    "Record Vitals & Run AI Triage"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2446B8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
          color: color.withValues(alpha: 0.08),
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

  Widget _priorityBadge(String priority, bool isManual) {
    final color = _priorityColor(priority);
    final label = isManual ? 'Manual' : priority;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ===================== VITALS SHEET =====================

class _VitalsSheet extends StatefulWidget {
  final DocumentSnapshot doc;

  const _VitalsSheet({required this.doc});

  @override
  State<_VitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends State<_VitalsSheet> {
  final _formKey = GlobalKey<FormState>();

  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _hrController = TextEditingController();
  final _rrController = TextEditingController();
  final _btController = TextEditingController();
  final _o2Controller = TextEditingController();

  int _ktasRn = 3;
  bool _isRunning = false;
  bool _finalizing = false;
  TriageResult? _stage2Result;
  String? _finalPrediction;

  @override
  void dispose() {
    _sbpController.dispose();
    _dbpController.dispose();
    _hrController.dispose();
    _rrController.dispose();
    _btController.dispose();
    _o2Controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _data =>
      widget.doc.data() as Map<String, dynamic>;

  Stage1Request _buildStage1() {
    final data = _data;
    if (data['noAITriage'] == true) {
      return const Stage1Request(
        chiefComplaint: 'general complaint',
        age: 50,
        sex: 1,
        pain: 2,
        nrsPain: 0.0,
        mental: 1,
        arrivalMode: 1,
        injury: 2,
        patientsPerHour: 8,
      );
    }
    final s1 = data['stage1Inputs'] as Map<String, dynamic>? ?? {};
    return Stage1Request(
      chiefComplaint:
          (s1['chief_complaint'] ?? 'general complaint') as String,
      age: (s1['age'] as num?)?.toInt() ?? 50,
      sex: (s1['sex'] as num?)?.toInt() ?? 1,
      pain: (s1['pain'] as num?)?.toInt() ?? 2,
      nrsPain: (s1['nrs_pain'] as num?)?.toDouble() ?? 0.0,
      mental: (s1['mental'] as num?)?.toInt() ?? 1,
      arrivalMode: (s1['arrival_mode'] as num?)?.toInt() ?? 1,
      injury: (s1['injury'] as num?)?.toInt() ?? 2,
      patientsPerHour: (s1['patients_per_hour'] as num?)?.toInt() ?? 8,
    );
  }

  Future<void> _runStage2AI() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRunning = true;
      _stage2Result = null;
    });

    final request = Stage2Request(
      stage1: _buildStage1(),
      sbp: double.parse(_sbpController.text.trim()),
      dbp: double.parse(_dbpController.text.trim()),
      hr: double.parse(_hrController.text.trim()),
      rr: double.parse(_rrController.text.trim()),
      bt: double.parse(_btController.text.trim()),
      saturation: double.parse(_o2Controller.text.trim()),
      ktasRn: _ktasRn,
    );

    final result = await TriageService.predictStage2(request);

    if (!mounted) return;

    if (result.isError) {
      setState(() => _isRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI error: ${result.errorMessage}")),
      );
      return;
    }

    setState(() {
      _isRunning = false;
      _stage2Result = result;
      _finalPrediction = result.prediction;
    });
  }

  Map<String, dynamic> _predictionToFirestore(String prediction) {
    switch (prediction) {
      case 'Emergency':
        return {'triageLevel': 'EMERGENCY', 'priorityNumber': 1};
      case 'Urgent':
        return {'triageLevel': 'MODERATE', 'priorityNumber': 2};
      default:
        return {'triageLevel': 'LOW', 'priorityNumber': 3};
    }
  }

  Future<void> _finalize() async {
    if (_stage2Result == null || _finalPrediction == null) return;
    setState(() => _finalizing = true);

    try {
      final data = _data;
      final patientId = data['patientId'] as String?;
      final patientName =
          data['patientName'] as String? ?? 'Unknown Patient';
      final oldTriageLevel = data['triageLevel'] as String? ?? 'LOW';
      final stage1Prediction = data['aiPrediction'] as String? ?? '';

      final result = _stage2Result!;
      final aiPrediction = result.prediction;
      final nurseOverride = _finalPrediction != aiPrediction;
      final firestoreFields = _predictionToFirestore(_finalPrediction!);
      final finalTriageLevel = firestoreFields['triageLevel'] as String;
      final finalPriorityNumber =
          firestoreFields['priorityNumber'] as int;

      final sbp = double.parse(_sbpController.text.trim());
      final dbp = double.parse(_dbpController.text.trim());
      final hr = double.parse(_hrController.text.trim());
      final rr = double.parse(_rrController.text.trim());
      final bt = double.parse(_btController.text.trim());
      final o2 = double.parse(_o2Controller.text.trim());

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Queue document — flat vitals + all required fields
      batch.update(db.collection('queue').doc(widget.doc.id), {
        'sbp': sbp,
        'dbp': dbp,
        'hr': hr,
        'rr': rr,
        'bt': bt,
        'o2': o2,
        'ktasRn': _ktasRn,
        'stage2AIResult': result.toFirestore(),
        'nurseOverride': nurseOverride,
        'finalTriageLevel': finalTriageLevel,
        'finalPriorityNumber': finalPriorityNumber,
        'triageLevel': finalTriageLevel,
        'priorityNumber': finalPriorityNumber,
        'status': 'waiting_doctor',
        'queueType': 'doctor',
        'nurseChecked': true,
        'nurseCheckedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Medical record
      batch.set(db.collection('medical_records').doc(), {
        'patientId': patientId,
        'patientName': patientName,
        'type': 'nurse_triage',
        'stage1Prediction': stage1Prediction,
        'stage2Prediction': aiPrediction,
        'finalTriageLevel': finalTriageLevel,
        'oldTriageLevel': oldTriageLevel,
        'confidence': result.confidence,
        'nurseOverride': nurseOverride,
        'vitalSigns': {
          'sbp': sbp,
          'dbp': dbp,
          'hr': hr,
          'rr': rr,
          'bt': bt,
          'o2': o2,
        },
        'ktasRn': _ktasRn,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notification when triage level changed
      if (oldTriageLevel != finalTriageLevel && patientId != null) {
        batch.set(db.collection('notifications').doc(), {
          'patientId': patientId,
          'type': 'triage_update',
          'message': 'Your triage priority has been updated.',
          'triageLevel': finalTriageLevel,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Triage finalized. Patient moved to doctor queue."),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error finalizing triage: $e")),
      );
    }
  }

  Color _predictionColor(String prediction) {
    switch (prediction) {
      case 'Emergency':
        return Colors.red;
      case 'Urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _ktasLabel(int level) {
    switch (level) {
      case 1:
        return '1 Resus';
      case 2:
        return '2 Emerg';
      case 3:
        return '3 Urgent';
      case 4:
        return '4 Less Urgent';
      default:
        return '5 Non-Urgent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName = _data['patientName'] as String? ?? 'Patient';
    final stage1Prediction = _data['aiPrediction'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Patient header
            Text(
              patientName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (stage1Prediction.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                "Stage 1: $stage1Prediction",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _predictionColor(stage1Prediction),
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              "Enter Vitals",
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Vitals form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _vitalField(
                            _sbpController, "SBP (mmHg)", "e.g. 120"),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _vitalField(
                            _dbpController, "DBP (mmHg)", "e.g. 80"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _vitalField(_hrController,
                            "Heart Rate (bpm)", "e.g. 72"),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _vitalField(_rrController,
                            "Resp. Rate (/min)", "e.g. 16"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _vitalField(
                          _btController,
                          "Body Temp (°C)",
                          "e.g. 37.0",
                          isDecimal: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _vitalField(
                          _o2Controller,
                          "O2 Sat (%)",
                          "e.g. 98",
                          isDecimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KTAS chips
                  const Text(
                    "Clinical Impression (KTAS)",
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(5, (i) {
                      final level = i + 1;
                      final selected = _ktasRn == level;
                      return ChoiceChip(
                        label: Text(_ktasLabel(level)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _ktasRn = level),
                        selectedColor: const Color(0xFF2446B8),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF2446B8)
                              : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Run AI button (shown before result)
                  if (_stage2Result == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runStage2AI,
                        icon: _isRunning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome,
                                color: Colors.white),
                        label: Text(
                          _isRunning
                              ? "Running AI…"
                              : "Run AI Assessment",
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2446B8),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // AI result + override + finalize
            if (_stage2Result != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(stage1Prediction),
              const SizedBox(height: 16),

              // Override dropdown — default is AI prediction
              DropdownButtonFormField<String>(
                initialValue: _finalPrediction,
                decoration: InputDecoration(
                  labelText: "Final Priority (override if needed)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Emergency',
                      child: Text("Emergency")),
                  DropdownMenuItem(
                      value: 'Urgent', child: Text("Urgent")),
                  DropdownMenuItem(
                      value: 'Non-Urgent',
                      child: Text("Non-Urgent")),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _finalPrediction = v);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Finalize button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _finalizing ? null : _finalize,
                  icon: _finalizing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle,
                          color: Colors.white),
                  label: Text(
                    _finalizing
                        ? "Finalizing…"
                        : "Finalize Triage → Doctor Queue",
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String stage1Prediction) {
    final result = _stage2Result!;
    final color = _predictionColor(result.prediction);
    final changed = stage1Prediction.isNotEmpty &&
        stage1Prediction != result.prediction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Stage 2 AI Result",
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.prediction.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${(result.confidence * 100).toStringAsFixed(1)}% confidence",
                style:
                    const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.confidence,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 8,
            ),
          ),
          if (changed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz,
                      color: Colors.amber.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Prediction changed: $stage1Prediction → ${result.prediction}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result.deferred) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded,
                      color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Low confidence — verify with clinical judgement",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vitalField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (double.tryParse(v.trim()) == null) return 'Invalid';
        return null;
      },
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
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(),
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
              status.toString().toLowerCase() == "active"
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
                      child: Icon(Icons.local_hospital,
                          size: 58, color: Colors.white),
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
                      style:
                          TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "● $statusText",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
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
      subtitle: Text(value,
          style:
              const TextStyle(fontSize: 17, color: Colors.black)),
    );
  }
}
