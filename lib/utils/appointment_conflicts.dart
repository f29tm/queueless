import 'package:cloud_firestore/cloud_firestore.dart';

/// Booking-time conflict checks for the appointment flow.
class AppointmentConflicts {
  AppointmentConflicts._();

  /// Returns the patient's existing scheduled appointment at exactly
  /// [date] + [time] — with any doctor — or null if there is none.
  ///
  /// A patient cannot be in two places at once, so the booking flow blocks
  /// a second booking at the same slot even if it's with a different doctor.
  /// Cancelled and completed appointments don't count.
  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> findPatientClash(
    FirebaseFirestore db, {
    required String patientId,
    required String date,
    required String time,
  }) async {
    final snap = await db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('date', isEqualTo: date)
        .where('time', isEqualTo: time)
        .where('status', isEqualTo: 'scheduled')
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }
}
