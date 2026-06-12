import 'package:cloud_functions/cloud_functions.dart';

class EncryptionService {
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  static HttpsCallable _fn(String name) =>
      _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 30)));

  // ─── Registration: save encrypted PII for a patient ─────────────────────
  static Future<void> saveUserPII({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveUserPII').call({'uid': uid, 'data': data});
  }

  // ─── Symptom assessment: save encrypted symptom data to queue doc ────────
  static Future<void> saveSymptomData({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveSymptomData').call({'docId': docId, 'data': data});
  }

  // ─── Doctor: save encrypted consultation notes ───────────────────────────
  static Future<void> saveConsultationNotes({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveConsultationNotes').call({'docId': docId, 'data': data});
  }

  // ─── Appointment: save encrypted reason ─────────────────────────────────
  static Future<void> saveAppointmentData({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveAppointmentData').call({'docId': docId, 'data': data});
  }

  // ─── Doctor: save encrypted prescription ────────────────────────────────
  static Future<void> savePrescription({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('savePrescription').call({'docId': docId, 'data': data});
  }

  // ─── Nurse: save encrypted vital signs to queue doc ─────────────────────
  static Future<void> saveVitalsData({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveVitalsData').call({'docId': docId, 'data': data});
  }

  // ─── Nurse: save encrypted clinical fields to medical_records doc ─────────
  static Future<void> saveMedicalRecord({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveMedicalRecord').call({'docId': docId, 'data': data});
  }

  // ─── Notifications: encrypt and write to user's notifications subcollection ─
  static Future<void> saveNotification({
    required List<String> userIds,
    required Map<String, dynamic> data,
  }) async {
    await _fn('saveNotification').call({'userIds': userIds, 'data': data});
  }

  // ─── Read + decrypt specific fields from any allowed collection ──────────
  static Future<Map<String, dynamic>> getDecryptedData({
    required String collection,
    required String docId,
    required List<String> fields,
  }) async {
    final result = await _fn('getDecryptedData').call({
      'collection': collection,
      'docId': docId,
      'fields': fields,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ─── Notifications: decrypt a single notification from subcollection ──────
  static Future<Map<String, dynamic>> getDecryptedNotification({
    required String userId,
    required String notificationId,
    required List<String> fields,
  }) async {
    final result = await _fn('getDecryptedData').call({
      'docPath': 'users/$userId/notifications/$notificationId',
      'fields': fields,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
