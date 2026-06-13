
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import '../../services/encryption_service.dart';
import '../../services/notification_service.dart';
import '../../utils/discharge_constants.dart';
import '../../utils/nurse_queue_filter.dart';
import '../../utils/nurse_selection_state.dart';
import '../../utils/queue_position_fanout.dart';
import '../../utils/triage_levels.dart';
import '../../widgets/nurse_multiselect_bar.dart';
import '../../widgets/nurse_queue_control_bar.dart';
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

DateTime _parseDateString(String date) {
  if (date.isEmpty) return DateTime(2000);
  try {
    // ISO format "YYYY-MM-DD"
    final iso = DateTime.tryParse(date);
    if (iso != null) return iso;
    // "EEE, MMM d" format e.g. "Sat, Jun 13" (how appointments are stored)
    final parsed = DateFormat('EEE, MMM d').parse(date);
    final now = DateTime.now();
    return DateTime(now.year, parsed.month, parsed.day);
  } catch (_) {}
  try {
    // "DD/MM/YYYY"
    final parts = date.split('/');
    if (parts.length == 3) {
      return DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
  } catch (_) {}
  return DateTime(2000);
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

class DoctorAppointmentsPage extends StatefulWidget {
  final VoidCallback onProfileTap;
  const DoctorAppointmentsPage({super.key, required this.onProfileTap});

  @override
  State<DoctorAppointmentsPage> createState() =>
      _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  String? _statusFilter; // null = All
  bool _newestFirst = true;

  List<QueryDocumentSnapshot> _applyFilterSort(
      List<QueryDocumentSnapshot> docs) {
    var result = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'scheduled') as String;
      if (_statusFilter != null && status != _statusFilter) return false;
      return true;
    }).toList();

    result.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = _parseDateString(aData['date'] ?? '');
      final bDate = _parseDateString(bData['date'] ?? '');
      return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;
    if (doctorUid == null) {
      return const Scaffold(
          body: Center(child: Text("No doctor logged in")));
    }

    final stream = FirebaseFirestore.instance
        .collection("appointments")
        .where("doctorUid", isEqualTo: doctorUid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = _countTodayItems(snapshot.data);
              return _blueHeader(
                context,
                "Appointments",
                doctorUid: doctorUid,
                rightText: "$count today",
                onProfileTap: widget.onProfileTap,
              );
            },
          ),
          _AppointmentFilterBar(
            statusFilter: _statusFilter,
            newestFirst: _newestFirst,
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            onSortChanged: (v) => setState(() => _newestFirst = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs =
                    _applyFilterSort(snapshot.data!.docs);
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

// ── Filter bar shared by appointments & consults ──────────────────────────────
class _AppointmentFilterBar extends StatelessWidget {
  final String? statusFilter;
  final bool newestFirst;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool> onSortChanged;

  const _AppointmentFilterBar({
    required this.statusFilter,
    required this.newestFirst,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  static const Color _primary = Color(0xFF2446B8);

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        backgroundColor: Colors.white,
        selectedColor: color,
        side: BorderSide(color: selected ? color : Colors.grey.shade300),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _chip(
              label: 'Newest',
              selected: newestFirst,
              color: _primary,
              onTap: () => onSortChanged(true),
            ),
            _chip(
              label: 'Oldest',
              selected: !newestFirst,
              color: _primary,
              onTap: () => onSortChanged(false),
            ),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.grey.shade300,
            ),
            _chip(
              label: 'All',
              selected: statusFilter == null,
              color: _primary,
              onTap: () => onStatusChanged(null),
            ),
            _chip(
              label: 'Scheduled',
              selected: statusFilter == 'scheduled',
              color: const Color(0xFF2446B8),
              onTap: () => onStatusChanged('scheduled'),
            ),
            _chip(
              label: 'Completed',
              selected: statusFilter == 'completed',
              color: const Color(0xFF2E7D32),
              onTap: () => onStatusChanged('completed'),
            ),
            _chip(
              label: 'Cancelled',
              selected: statusFilter == 'cancelled',
              color: const Color(0xFFC62828),
              onTap: () => onStatusChanged('cancelled'),
            ),
          ],
        ),
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
  String _selectedSort = 'priority';
  String? _selectedFilter;

  NurseSelectionState _selection = NurseSelectionState.empty();
  bool get _isMultiSelectMode => !_selection.isEmpty;
  List<QueryDocumentSnapshot<Object?>> _visibleDocs = const [];

  void _toggleSelect(String id) =>
      setState(() => _selection = _selection.toggleSelection(id));

  void _cancelMultiSelect() =>
      setState(() => _selection = _selection.clearSelection());

  void _selectAllVisible() =>
      setState(() => _selection = _selection.selectAll(_visibleDocs.map((d) => d.id)));

  Future<void> _confirmDischarge() async {
    final ids = _selection.selected.toList();
    if (ids.isEmpty) return;
    final count = ids.length;
    final plural = count == 1 ? '' : 's';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discharge Patients'),
        content: Text(
          'Discharge $count patient$plural? This will mark them as left '
          'without being seen and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dataById = {
        for (final d in _visibleDocs)
          d.id: (d.data() as Map<String, dynamic>?) ?? const <String, dynamic>{},
      };
      final dischargedBy = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final id in ids) {
        final data = dataById[id] ?? const <String, dynamic>{};

        batch.update(firestore.collection('queue').doc(id), {
          'status': dischargeStatus(),
          'queueType': 'discharged',
          'dischargedAt': FieldValue.serverTimestamp(),
          'dischargeReason': dischargeReason(),
        });

        final s1 =
            data['stage1Inputs'] as Map<String, dynamic>? ?? const {};
        final chiefComplaint =
            (s1['chief_complaint'] as String?)?.trim() ?? '';
        final stage2Result =
            data['stage2AIResult'] as Map<String, dynamic>?;

        batch.set(firestore.collection('medical_records').doc(), {
          'patientId': data['patientId'],
          'patientName': data['patientName'] ?? 'Unknown Patient',
          'queueDocId': id,
          'action': 'discharge_lwbs',
          'outcome': 'left_without_being_seen',
          'stage': 2,
          'dischargedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'dischargedBy': dischargedBy,
          'triageLevel':
              data['finalTriageLevel'] ?? data['triageLevel'] ?? 'LOW',
          'chiefComplaint': chiefComplaint,
          if (data['aiPrediction'] != null)
            'stage1Prediction': data['aiPrediction'],
          if (stage2Result?['prediction'] != null)
            'stage2Prediction': stage2Result!['prediction'],
          'note': dischargeReason(),
        });
      }

      await batch.commit();
      _cancelMultiSelect();
      QueuePositionFanout.run(NotificationService()).ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count patient$plural discharged')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Discharge failed: $e')));
      }
    }
  }

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
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<QueryDocumentSnapshot<Object?>> _applySort(
      List<QueryDocumentSnapshot<Object?>> docs) {
    if (_selectedSort == 'priority') return NurseQueueFilter.sortByPriority(docs);
    if (_selectedSort == 'wait') {
      // Sort by how long the patient has been waiting for a doctor,
      // measured from when the nurse finished (triageCompletedAt).
      // Longest wait first.
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = List.of(docs);
      list.sort((a, b) {
        final aData = (a.data() as Map<String, dynamic>?) ?? const {};
        final bData = (b.data() as Map<String, dynamic>?) ?? const {};
        final ta = aData['triageCompletedAt'];
        final tb = bData['triageCompletedAt'];
        final aWait = ta is Timestamp ? now - ta.millisecondsSinceEpoch : 0;
        final bWait = tb is Timestamp ? now - tb.millisecondsSinceEpoch : 0;
        return bWait.compareTo(aWait); // longest wait first
      });
      return list;
    }
    return NurseQueueFilter.sortByArrival(docs);
  }

  Widget _buildMultiSelectHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 56, left: 8, right: 8, bottom: 14),
      color: const Color(0xFF2446B8),
      child: Row(
        children: [
          TextButton(
            onPressed: _cancelMultiSelect,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text("Cancel", style: TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Text(
              "${_selection.count} selected",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: _selectAllVisible,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text("Select All", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Stack(
        children: [
          Column(
            children: [
              _isMultiSelectMode
                  ? _buildMultiSelectHeader()
                  : _blueHeader(
                      context,
                      "Patient Queue",
                      doctorUid: doctorUid,
                      subtitle: "Sorted by severity",
                      onProfileTap: widget.onProfileTap,
                    ),
              NurseQueueControlBar(
                selectedSort: _selectedSort,
                selectedFilter: _selectedFilter,
                onSortChanged: (v) => setState(() => _selectedSort = v),
                onFilterChanged: (v) => setState(() => _selectedFilter = v),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text("Error loading queue",
                              style: TextStyle(color: Colors.grey, fontSize: 16)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2446B8)));
                    }

                    final allDocs = snapshot.data!.docs;
                    final filtered = NurseQueueFilter.filterByLevel(
                        allDocs, _selectedFilter);
                    final docs = _applySort(filtered);
                    _visibleDocs = docs;

                    int emergencyCount = 0, urgentCount = 0;
                    for (final doc in allDocs) {
                      final level =
                          _effectiveLevel(doc.data() as Map<String, dynamic>);
                      if (level == TriageLevels.emergency) emergencyCount++;
                      if (level == TriageLevels.moderate) urgentCount++;
                    }

                    if (allDocs.isEmpty) {
                      return const Center(
                          child: Text("No patients waiting for doctor",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)));
                    }

                    return Column(
                      children: [
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
                                  number: '${allDocs.length}',
                                  label: "Active",
                                  color: const Color(0xFF2446B8)),
                            ],
                          ),
                        ),
                        if (docs.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                "No patients match this filter",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                  20, 0, 20, _isMultiSelectMode ? 96 : 20),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final level = _effectiveLevel(data);
                                final borderColor = _levelColor(level);
                                final patientName =
                                    data['patientName'] as String? ?? 'Unknown';
                                final patientId =
                                    data['patientId'] as String? ?? '';
                                final queueDocId = doc.id;
                                final completedAt =
                                    data['triageCompletedAt'] as Timestamp?;
                                final rawSymptoms = data['symptoms'];
                                final symptomList = rawSymptoms is List
                                    ? rawSymptoms
                                        .map((s) => s.toString())
                                        .toList()
                                    : <String>[];
                                final symptoms = symptomList.join(', ');
                                final nurseOverride =
                                    data['nurseOverride'] as bool? ?? false;
                                final isSelected =
                                    _selection.contains(queueDocId);

                                return GestureDetector(
                                  onTap: () => _isMultiSelectMode
                                      ? _toggleSelect(queueDocId)
                                      : Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DoctorPatientDetailScreen(
                                              queueDocId: queueDocId,
                                              patientId: patientId,
                                              patientName: patientName,
                                              triageLevel: level,
                                              symptoms: symptomList,
                                            ),
                                          ),
                                        ),
                                  onLongPress: () =>
                                      _toggleSelect(queueDocId),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (_isMultiSelectMode) ...[
                                              SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (_) =>
                                                      _toggleSelect(queueDocId),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: borderColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(_levelLabel(level),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
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
                                                child: Text("Nurse overridden",
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .amber.shade900,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ),
                                            ],
                                            const Spacer(),
                                            Text(_timeAgo(completedAt),
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13)),
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
                                                  color: Colors.grey,
                                                  fontSize: 14),
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
              ),
            ],
          ),
          NurseMultiSelectBar(
            active: _isMultiSelectMode,
            count: _selection.count,
            onDischarge: _confirmDischarge,
          ),
        ],
      ),
    );
  }
}

// ===================== CONSULTS PAGE =====================

class DoctorConsultsPage extends StatefulWidget {
  final VoidCallback onProfileTap;
  const DoctorConsultsPage({super.key, required this.onProfileTap});

  @override
  State<DoctorConsultsPage> createState() => _DoctorConsultsPageState();
}

class _DoctorConsultsPageState extends State<DoctorConsultsPage> {
  String? _statusFilter;
  bool _newestFirst = true;

  List<QueryDocumentSnapshot> _applyFilterSort(
      List<QueryDocumentSnapshot> docs) {
    var result = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'scheduled') as String;
      if (_statusFilter != null && status != _statusFilter) return false;
      return true;
    }).toList();

    result.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = _parseDateString(aData['date'] ?? '');
      final bDate = _parseDateString(bData['date'] ?? '');
      return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid;
    if (doctorUid == null) {
      return const Scaffold(
          body: Center(child: Text("No doctor logged in")));
    }

    final stream = FirebaseFirestore.instance
        .collection("consultations")
        .where("doctorUid", isEqualTo: doctorUid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FC),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = _countTodayItems(snapshot.data);
              return _blueHeader(
                context,
                "Consults",
                doctorUid: doctorUid,
                rightText: "$count today",
                onProfileTap: widget.onProfileTap,
              );
            },
          ),
          _AppointmentFilterBar(
            statusFilter: _statusFilter,
            newestFirst: _newestFirst,
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            onSortChanged: (v) => setState(() => _newestFirst = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _applyFilterSort(snapshot.data!.docs);
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
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "REASON",
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: (':'.allMatches(reason).length == 2)
                            ? EncryptionService.getDecryptedData(
                                collection: 'appointments',
                                docId: docId,
                                fields: ['reason'],
                              ).then((d) =>
                                  (d['reason'] as String?) ?? reason)
                            : Future.value(reason),
                        builder: (_, snap) => Text(
                          snap.data ?? reason,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
