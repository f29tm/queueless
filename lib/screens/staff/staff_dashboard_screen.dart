import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/triage_service.dart';
import '../login_screen.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          title: const Text('Live Queue Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth =
                  Provider.of<AuthProvider>(context, listen: false);
              await auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('queue')
              .where('queueType', isEqualTo: 'nurse')
              .where('status', isEqualTo: 'waiting_nurse')
              .orderBy('priorityNumber')
              .orderBy('createdAt')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading queue."));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.teal),
              );
            }

            final docs = snapshot.data!.docs;
            final emergencies = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['triageLevel'] == 'EMERGENCY';
            }).length;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade200,
                  width: double.infinity,
                  child: Text(
                    "Patients Waiting: ${docs.length} | Emergencies: $emergencies",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (docs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "No patients in queue.",
                        style:
                            TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) =>
                          _PatientCard(doc: docs[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── PATIENT CARD ─────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final DocumentSnapshot doc;

  const _PatientCard({required this.doc});

  Color _levelColor(String level) {
    switch (level) {
      case 'EMERGENCY':
        return Colors.red;
      case 'MODERATE':
        return Colors.orange;
      case 'PENDING':
        return Colors.grey.shade400;
      default:
        return Colors.green;
    }
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'EMERGENCY':
        return 'EMERGENCY';
      case 'MODERATE':
        return 'URGENT';
      case 'LOW':
        return 'NON-URGENT';
      case 'PENDING':
        return 'Manual Assessment';
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['patientName'] as String? ?? 'Unknown';
    final level = data['triageLevel'] as String? ?? 'LOW';
    final symptoms =
        (data['symptoms'] as List?)?.cast<String>().join(', ') ?? '';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final deferred = data['deferred'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _VitalsSheet(doc: doc),
        ),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    children: [
                      if (deferred)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.amber.shade800),
                              const SizedBox(width: 4),
                              Text(
                                "Review",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _levelColor(level),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (level == 'PENDING') ...[
                              const Icon(Icons.person_outline,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _levelLabel(level),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (symptoms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Symptoms: $symptoms",
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                (data['noAITriage'] == true ||
                        data['aiPrediction'] == null ||
                        (confidence == 0.0 && level == 'PENDING'))
                    ? "Awaiting nurse assessment"
                    : "AI Stage 1 confidence: ${(confidence * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                "Tap to enter vitals →",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.teal.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── VITALS BOTTOM SHEET ──────────────────────────────────────────────────────

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
  String? _finalPriority;

  bool _runningAI = false;
  bool _finalizing = false;
  TriageResult? _stage2Result;
  String? _aiError;

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

  Stage1Request _stage1FromDoc() {
    final inputs =
        _data['stage1Inputs'] as Map<String, dynamic>? ?? {};
    return Stage1Request(
      chiefComplaint:
          inputs['chief_complaint'] as String? ?? 'general complaint',
      age: (inputs['age'] as num?)?.toInt() ?? 50,
      sex: (inputs['sex'] as num?)?.toInt() ?? 1,
      pain: (inputs['pain'] as num?)?.toInt() ?? 2,
      nrsPain: (inputs['nrs_pain'] as num?)?.toDouble() ?? 0.0,
      mental: (inputs['mental'] as num?)?.toInt() ?? 1,
      arrivalMode: (inputs['arrival_mode'] as num?)?.toInt() ?? 1,
      injury: (inputs['injury'] as num?)?.toInt() ?? 2,
      patientsPerHour:
          (inputs['patients_per_hour'] as num?)?.toInt() ?? 8,
    );
  }

  Future<void> _runStage2AI() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _runningAI = true;
      _stage2Result = null;
      _aiError = null;
    });

    final request = Stage2Request(
      stage1: _stage1FromDoc(),
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

    setState(() {
      _runningAI = false;
      if (result.isError) {
        _aiError = result.errorMessage;
      } else {
        _stage2Result = result;
        _finalPriority = result.prediction;
      }
    });
  }

  Future<void> _finalizeTriage() async {
    if (_stage2Result == null) return;

    setState(() => _finalizing = true);

    try {
      final aiPrediction = _stage2Result!.prediction;
      final nurseOverride = _finalPriority != aiPrediction;
      final finalTriage =
          _predictionToTriage(_finalPriority ?? aiPrediction);

      await FirebaseFirestore.instance
          .collection('queue')
          .doc(widget.doc.id)
          .update({
        'sbp': double.parse(_sbpController.text.trim()),
        'dbp': double.parse(_dbpController.text.trim()),
        'hr': double.parse(_hrController.text.trim()),
        'rr': double.parse(_rrController.text.trim()),
        'bt': double.parse(_btController.text.trim()),
        'o2': double.parse(_o2Controller.text.trim()),
        'ktasRn': _ktasRn,
        'stage2AIResult': _stage2Result!.toFirestore(),
        'nurseOverride': nurseOverride,
        'finalTriageLevel': finalTriage['level'],
        'finalPriorityNumber': finalTriage['priority'],
        'status': 'waiting_doctor',
        'queueType': 'doctor',
        'triageCompletedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to finalize: $e")),
      );
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  Map<String, dynamic> _predictionToTriage(String prediction) {
    switch (prediction) {
      case 'Emergency':
        return {'level': 'EMERGENCY', 'priority': 1};
      case 'Urgent':
        return {'level': 'MODERATE', 'priority': 2};
      default:
        return {'level': 'LOW', 'priority': 3};
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

  @override
  Widget build(BuildContext context) {
    final name = _data['patientName'] as String? ?? 'Unknown';
    final level = _data['triageLevel'] as String? ?? 'LOW';
    final stage1Prediction = _data['aiPrediction'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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

            Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "Stage 1: $stage1Prediction  ·  $level",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _predictionColor(stage1Prediction),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Enter Vitals",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _vitalsRow(
                    left: _vitalField(
                        _sbpController, "SBP (mmHg)", "e.g. 120"),
                    right: _vitalField(
                        _dbpController, "DBP (mmHg)", "e.g. 80"),
                  ),
                  const SizedBox(height: 12),
                  _vitalsRow(
                    left: _vitalField(
                        _hrController, "Heart Rate (bpm)", "e.g. 72"),
                    right: _vitalField(
                        _rrController, "Resp. Rate (/min)", "e.g. 16"),
                  ),
                  const SizedBox(height: 12),
                  _vitalsRow(
                    left: _vitalField(
                        _btController, "Body Temp (°C)", "e.g. 37.0",
                        isDecimal: true),
                    right: _vitalField(
                        _o2Controller, "O2 Sat (%)", "e.g. 98",
                        isDecimal: true),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: _ktasRn,
                    decoration: InputDecoration(
                      labelText: "Nurse Clinical Impression (KTAS)",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 1,
                          child: Text("1 — Resuscitation")),
                      DropdownMenuItem(
                          value: 2, child: Text("2 — Emergency")),
                      DropdownMenuItem(
                          value: 3, child: Text("3 — Urgent")),
                      DropdownMenuItem(
                          value: 4, child: Text("4 — Semi-urgent")),
                      DropdownMenuItem(
                          value: 5, child: Text("5 — Non-urgent")),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _ktasRn = v);
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runningAI ? null : _runStage2AI,
                      icon: _runningAI
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome,
                              color: Colors.white),
                      label: Text(
                        _runningAI ? "Running AI…" : "Run Stage 2 AI",
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
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

            // AI error
            if (_aiError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  "AI error: $_aiError",
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],

            // Stage 2 result + override + finalize
            if (_stage2Result != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(stage1Prediction),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _finalPriority,
                decoration: InputDecoration(
                  labelText: "Final Priority (override if needed)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                  if (v != null) setState(() => _finalPriority = v);
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finalizing ? null : _finalizeTriage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _finalizing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Text(
                          "Finalize Triage → Send to Doctor",
                          style: TextStyle(
                              fontSize: 16, color: Colors.white),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Stage 2 AI Result",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${(result.confidence * 100).toStringAsFixed(1)}% confidence",
                style: const TextStyle(
                    fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          if (changed) ...[
            const SizedBox(height: 10),
            _warningBanner(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              text:
                  "Result changed: $stage1Prediction → ${result.prediction}",
            ),
          ],
          if (result.deferred) ...[
            const SizedBox(height: 8),
            _warningBanner(
              icon: Icons.warning_rounded,
              color: Colors.red,
              text:
                  "Low confidence — verify with clinical judgement",
            ),
          ],
        ],
      ),
    );
  }

  Widget _warningBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsRow({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
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
