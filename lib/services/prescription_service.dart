import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'encryption_service.dart';

class Prescription {
  // Standard dose hours by frequency
  static const _hours1 = [8];
  static const _hours2 = [8, 20];
  static const _hours3 = [8, 14, 20];
  static const _hours4 = [8, 12, 16, 20];

  final String id;
  final String patientId;
  final String patientName;
  final String medicationName;
  final String dosageInstructions;
  final int timesPerDay;
  final DateTime startDate;
  final DateTime? endDate;
  final String prescribedByUid;
  final String prescribedByName;
  final int totalDoses; // 0 = ongoing (no fixed total)
  final List<DateTime> doseTakenLog;
  final bool active;

  const Prescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.medicationName,
    required this.dosageInstructions,
    required this.timesPerDay,
    required this.startDate,
    this.endDate,
    required this.prescribedByUid,
    required this.prescribedByName,
    required this.totalDoses,
    required this.doseTakenLog,
    required this.active,
  });

  Prescription copyWith({String? medicationName, String? dosageInstructions}) {
    return Prescription(
      id: id, patientId: patientId, patientName: patientName,
      medicationName: medicationName ?? this.medicationName,
      dosageInstructions: dosageInstructions ?? this.dosageInstructions,
      timesPerDay: timesPerDay, startDate: startDate, endDate: endDate,
      prescribedByUid: prescribedByUid, prescribedByName: prescribedByName,
      totalDoses: totalDoses, doseTakenLog: doseTakenLog, active: active,
    );
  }

  factory Prescription.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Prescription(
      id: doc.id,
      patientId: d['patientId'] ?? '',
      patientName: d['patientName'] ?? '',
      medicationName: d['medicationName'] ?? '',
      dosageInstructions: d['dosageInstructions'] ?? '',
      timesPerDay: (d['timesPerDay'] as num?)?.toInt() ?? 1,
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      prescribedByUid: d['prescribedByUid'] ?? '',
      prescribedByName: d['prescribedByName'] ?? '',
      totalDoses: (d['totalDoses'] as num?)?.toInt() ?? 0,
      doseTakenLog: ((d['doseTakenLog'] as List?) ?? [])
          .map((t) => (t as Timestamp).toDate())
          .toList(),
      active: d['active'] ?? true,
    );
  }

  List<int> get _scheduledHours {
    switch (timesPerDay) {
      case 1:  return _hours1;
      case 2:  return _hours2;
      case 3:  return _hours3;
      default: return _hours4;
    }
  }

  bool get isActiveToday {
    if (!active) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (today.isBefore(start)) return false;
    if (endDate == null) return true;
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !today.isAfter(end);
  }

  int get todayDosesTaken {
    final now = DateTime.now();
    return doseTakenLog
        .where((d) => d.year == now.year && d.month == now.month && d.day == now.day)
        .length;
  }

  bool get allTodayDosesTaken => todayDosesTaken >= timesPerDay;

  // -1 means ongoing with no fixed total
  int get dosesRemaining =>
      totalDoses == 0 ? -1 : (totalDoses - doseTakenLog.length).clamp(0, totalDoses);

  bool get needsRefill => dosesRemaining != -1 && dosesRemaining <= 5;

  // Returns "8:00 AM" style label for the next scheduled dose today, or null if all done
  String? get nextDoseLabel {
    if (!isActiveToday || allTodayDosesTaken) return null;
    final hours = _scheduledHours;
    final nextIndex = todayDosesTaken.clamp(0, hours.length - 1);
    final now = DateTime.now();
    final nextTime = DateTime(now.year, now.month, now.day, hours[nextIndex]);
    return DateFormat.jm().format(nextTime);
  }

  String get durationLabel {
    if (endDate == null) return 'Ongoing';
    return '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d').format(endDate!)}';
  }

  String get remainingLabel {
    if (dosesRemaining == -1) {
      if (endDate == null) return 'Ongoing';
      final days = endDate!.difference(DateTime.now()).inDays;
      if (days <= 0) return 'Prescription ended';
      return 'Refill in $days days';
    }
    return '$dosesRemaining doses left';
  }
}

class PrescriptionService {
  final _col = FirebaseFirestore.instance.collection('prescriptions');

  // Client-side sort avoids needing a composite Firestore index.
  // asyncMap decrypts sensitive fields for each prescription after loading.
  Stream<List<Prescription>> streamForPatient(String patientId) {
    return _col
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .asyncMap((s) async {
      final raw = s.docs
          .map(Prescription.fromFirestore)
          .where((p) => p.active)
          .toList();

      final decrypted = await Future.wait(raw.map((p) async {
        if (':'.allMatches(p.medicationName).length != 2) return p;
        try {
          final d = await EncryptionService.getDecryptedData(
            collection: 'prescriptions',
            docId: p.id,
            fields: ['medicationName', 'dosageInstructions'],
          );
          return p.copyWith(
            medicationName: d['medicationName'] as String? ?? p.medicationName,
            dosageInstructions: d['dosageInstructions'] as String? ?? p.dosageInstructions,
          );
        } catch (_) {
          return p;
        }
      }));

      decrypted.sort((a, b) => b.startDate.compareTo(a.startDate));
      return decrypted;
    });
  }

  Future<void> writePrescription({
    required String patientId,
    required String patientName,
    required String medicationName,
    required String dosageInstructions,
    required int timesPerDay,
    required DateTime startDate,
    required int durationDays, // 0 = ongoing
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final doctorName = (snap.data()?['name'] as String?) ?? 'Doctor';

    final endDate = durationDays > 0 ? startDate.add(Duration(days: durationDays)) : null;
    final totalDoses = durationDays > 0 ? timesPerDay * durationDays : 0;

    // Generate doc ref so we can write non-sensitive and sensitive fields separately
    final ref = _col.doc();

    await ref.set({
      'patientId': patientId,
      'patientName': patientName,
      'timesPerDay': timesPerDay,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'prescribedByUid': uid,
      'prescribedByName': doctorName,
      'totalDoses': totalDoses,
      'doseTakenLog': [],
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Encrypt sensitive medication fields via Cloud Function
    await EncryptionService.savePrescription(
      docId: ref.id,
      data: {
        'medicationName': medicationName,
        'dosageInstructions': dosageInstructions,
      },
    );

    FirebaseFirestore.instance.collection('audit_logs').add({
      'action': 'prescription_created',
      'prescriptionId': ref.id,
      'patientId': patientId,
      'patientName': patientName,
      'prescribedByUid': uid,
      'prescribedByName': doctorName,
      'timestamp': FieldValue.serverTimestamp(),
    }).ignore();
  }

  Future<void> markDoseTaken(String prescriptionId) async {
    await _col.doc(prescriptionId).update({
      'doseTakenLog': FieldValue.arrayUnion([Timestamp.fromDate(DateTime.now())]),
    });
  }
}
