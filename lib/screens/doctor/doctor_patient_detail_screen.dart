import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/prescription_service.dart';
import '../../utils/triage_levels.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final String queueDocId;
  final String patientId;
  final String patientName;
  final String triageLevel;
  final List<String> symptoms;

  const DoctorPatientDetailScreen({
    super.key,
    required this.queueDocId,
    required this.patientId,
    required this.patientName,
    required this.triageLevel,
    required this.symptoms,
  });

  @override
  State<DoctorPatientDetailScreen> createState() =>
      _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  bool _discharging = false;

  Color get _levelColor => TriageLevels.color(widget.triageLevel);

  String get _levelLabel => TriageLevels.labelEn(widget.triageLevel);

  Future<void> _dischargePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discharge Patient'),
        content: Text('Discharge ${widget.patientName} and close this case?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2446B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Discharge',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _discharging = true);
    try {
      await FirebaseFirestore.instance
          .collection('queue')
          .doc(widget.queueDocId)
          .update({
            'status': 'discharged',
            'dischargedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _discharging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to discharge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openPrescriptionForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PrescriptionForm(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2446B8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.patientName),
      ),
      body: Column(
        children: [
          // ── Patient summary header ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: const Color(0xFF2446B8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _levelColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _levelLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Symptoms: ${widget.symptoms.join(', ')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),

          // ── Prescriptions list ───────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Prescription>>(
              stream: PrescriptionService().streamForPatient(widget.patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2446B8)),
                  );
                }
                final list = snapshot.data ?? [];
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Prescriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No prescriptions yet.\nTap "Add Prescription" to write one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...list.map((p) => _PrescriptionCard(p)),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // ── Bottom action bar ────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _discharging ? null : _dischargePatient,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: _discharging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Text(
                          'Discharge',
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
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openPrescriptionForm,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Prescription',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2446B8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
}

// ── Prescription summary card (read-only, shown in doctor view) ───────────────

class _PrescriptionCard extends StatelessWidget {
  final Prescription p;
  const _PrescriptionCard(this.p);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.grey.withValues(alpha: 0.1),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.medicationName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            p.dosageInstructions,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                p.durationLabel,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.medication, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                p.timesPerDay == 1
                    ? 'Once daily'
                    : p.timesPerDay == 2
                    ? 'Twice daily'
                    : '${p.timesPerDay}x daily',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Prescription form (bottom sheet) ─────────────────────────────────────────

class _PrescriptionForm extends StatefulWidget {
  final String patientId;
  final String patientName;

  const _PrescriptionForm({required this.patientId, required this.patientName});

  @override
  State<_PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends State<_PrescriptionForm> {
  final _formKey = GlobalKey<FormState>();
  final _medController = TextEditingController();
  final _instrController = TextEditingController();
  int _timesPerDay = 1;
  int _durationDays = 7;
  bool _saving = false;

  static const _durationValues = [7, 14, 30, 0];
  static const _durationLabels = ['7 days', '14 days', '30 days', 'Ongoing'];

  @override
  void dispose() {
    _medController.dispose();
    _instrController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PrescriptionService().writePrescription(
        patientId: widget.patientId,
        patientName: widget.patientName,
        medicationName: _medController.text.trim(),
        dosageInstructions: _instrController.text.trim(),
        timesPerDay: _timesPerDay,
        startDate: DateTime.now(),
        durationDays: _durationDays,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved'),
            backgroundColor: Color(0xFF2446B8),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Write Prescription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Medication name + dosage
            TextFormField(
              controller: _medController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecor(
                'Medication name & dosage',
                hint: 'e.g. Amoxicillin 500mg',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Instructions
            TextFormField(
              controller: _instrController,
              decoration: _inputDecor(
                'Instructions',
                hint: 'e.g. 1 capsule • 3 times daily',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Times per day + duration
            Row(
              children: [
                Expanded(
                  child: _LabeledDropdown<int>(
                    label: 'Times per day',
                    value: _timesPerDay,
                    items: const [1, 2, 3, 4],
                    labels: const ['Once', 'Twice', '3×', '4×'],
                    onChanged: (v) => setState(() => _timesPerDay = v!),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LabeledDropdown<int>(
                    label: 'Duration',
                    value: _durationDays,
                    items: _durationValues,
                    labels: _durationLabels,
                    onChanged: (v) => setState(() => _durationDays = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2446B8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Prescription',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2446B8), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ── Small reusable labeled dropdown ──────────────────────────────────────────

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: List.generate(
                items.length,
                (i) =>
                    DropdownMenuItem(value: items[i], child: Text(labels[i])),
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Public helper — opens the prescription form from any doctor screen ────────

Future<void> showPrescriptionForm(
  BuildContext context, {
  required String patientId,
  required String patientName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _PrescriptionForm(patientId: patientId, patientName: patientName),
  );
}
