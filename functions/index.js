const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const ENCRYPTION_KEY = defineSecret('ENCRYPTION_KEY');

// AES-256-GCM — format: iv(base64):authTag(base64):ciphertext(base64)
function encrypt(text, keyBuf) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', keyBuf, iv);
  const enc = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}:${tag.toString('base64')}:${enc.toString('base64')}`;
}

function decrypt(encoded, keyBuf) {
  const [ivB64, tagB64, cipherB64] = encoded.split(':');
  const iv = Buffer.from(ivB64, 'base64');
  const tag = Buffer.from(tagB64, 'base64');
  const ciphertext = Buffer.from(cipherB64, 'base64');
  const decipher = crypto.createDecipheriv('aes-256-gcm', keyBuf, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
}

function encryptFields(data, fields, keyBuf) {
  const result = { ...data };
  for (const f of fields) {
    if (result[f] != null && result[f] !== '') {
      result[f] = encrypt(String(result[f]), keyBuf);
    }
  }
  return result;
}

function isEncrypted(value) {
  return typeof value === 'string' && (value.match(/:/g) || []).length === 2;
}

// ─── saveUserPII — called at patient registration ────────────────────────────
exports.saveUserPII = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { uid, data } = req.data;
  if (uid !== req.auth.uid) throw new HttpsError('permission-denied', 'UID mismatch');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['dob', 'nationality', 'gender', 'phone'], key);

  await admin.firestore().collection('users').doc(uid).set(encrypted, { merge: true });
  return { success: true };
});

// ─── saveSymptomData — called after symptom assessment ───────────────────────
exports.saveSymptomData = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;
  if (data.patientId !== req.auth.uid) throw new HttpsError('permission-denied', 'UID mismatch');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['symptoms', 'description', 'chiefComplaint'], key);

  // Use update() so dot-notation can clear the plaintext chief_complaint
  // inside stage1Inputs — the encrypted copy is stored in chiefComplaint above.
  const updatePayload = { ...encrypted, 'stage1Inputs.chief_complaint': '' };
  await admin.firestore().collection('queue').doc(docId).update(updatePayload);
  return { success: true };
});

// ─── saveConsultationNotes — called by patient (booking notes) or doctor/nurse
exports.saveConsultationNotes = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;

  const userSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
  const role = userSnap.data()?.role;
  const isStaff = ['nurse', 'doctor', 'staff'].includes(role);
  const isPatient = role === 'patient';

  if (!isStaff && !isPatient) throw new HttpsError('permission-denied', 'Access denied');

  // Patients can only write notes to their own consultations
  if (isPatient) {
    const snap = await admin.firestore().collection('consultations').doc(docId).get();
    if (!snap.exists || snap.data().patientId !== req.auth.uid) {
      throw new HttpsError('permission-denied', 'Not your consultation');
    }
  }

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['notes', 'diagnosis', 'symptoms'], key);

  await admin.firestore().collection('consultations').doc(docId).set(encrypted, { merge: true });
  return { success: true };
});

// ─── savePrescription — called by doctor ────────────────────────────────────
exports.savePrescription = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;

  const userSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
  const isStaff = ['nurse', 'doctor', 'staff'].includes(userSnap.data()?.role);
  if (!isStaff) throw new HttpsError('permission-denied', 'Staff only');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['medicationName', 'dosageInstructions', 'notes'], key);

  await admin.firestore().collection('prescriptions').doc(docId).set(encrypted, { merge: true });
  return { success: true };
});

// ─── saveVitalsData — called by nurse after recording vital signs ────────────
exports.saveVitalsData = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;

  const userSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
  const isStaff = ['nurse', 'doctor', 'staff'].includes(userSnap.data()?.role);
  if (!isStaff) throw new HttpsError('permission-denied', 'Staff only');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['sbp', 'dbp', 'hr', 'rr', 'bt', 'o2'], key);

  await admin.firestore().collection('queue').doc(docId).set(encrypted, { merge: true });
  return { success: true };
});

// ─── saveMedicalRecord — called by nurse on triage finalisation ──────────────
exports.saveMedicalRecord = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;

  const userSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
  const isStaff = ['nurse', 'doctor', 'staff'].includes(userSnap.data()?.role);
  if (!isStaff) throw new HttpsError('permission-denied', 'Staff only');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');

  // Serialise nested map to JSON string so it can be encrypted as a single value
  const processedData = { ...data };
  if (processedData.vitalSigns && typeof processedData.vitalSigns === 'object') {
    processedData.vitalSigns = JSON.stringify(processedData.vitalSigns);
  }

  const encrypted = encryptFields(
    processedData,
    ['stage1Prediction', 'stage2Prediction', 'finalTriageLevel', 'oldTriageLevel',
     'confidence', 'nurseOverride', 'vitalSigns', 'ktasRn'],
    key,
  );

  await admin.firestore().collection('medical_records').doc(docId).set(encrypted, { merge: true });
  return { success: true };
});

// ─── saveAppointmentData — called by patient when booking an appointment ────
exports.saveAppointmentData = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { docId, data } = req.data;

  if (data.patientId !== req.auth.uid) throw new HttpsError('permission-denied', 'UID mismatch');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['reason'], key);

  await admin.firestore().collection('appointments').doc(docId).set(encrypted, { merge: true });
  return { success: true };
});

// ─── saveNotification — encrypt notification content and write to subcollection
exports.saveNotification = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { userIds, data } = req.data;

  if (!Array.isArray(userIds) || userIds.length === 0) {
    throw new HttpsError('invalid-argument', 'userIds must be a non-empty array');
  }

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const encrypted = encryptFields(data, ['title', 'body', 'titleAr', 'bodyAr'], key);
  encrypted.createdAt = admin.firestore.FieldValue.serverTimestamp();

  const db = admin.firestore();
  const batch = db.batch();
  for (const uid of userIds) {
    const ref = db.collection('users').doc(uid).collection('notifications').doc();
    batch.set(ref, encrypted);
  }
  await batch.commit();
  return { success: true };
});

// ─── getDecryptedData — read + decrypt for authorized caller ─────────────────
exports.getDecryptedData = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { collection, docId, fields, docPath } = req.data;

  let snap;

  if (docPath) {
    // Subcollection path support — only users/{uid}/... paths are allowed
    const segments = docPath.split('/');
    if (segments[0] !== 'users' || segments.length < 4) {
      throw new HttpsError('invalid-argument', 'Invalid docPath');
    }
    const pathUserId = segments[1];
    const callerSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
    const isStaff = ['nurse', 'doctor', 'staff'].includes(callerSnap.data()?.role);
    if (pathUserId !== req.auth.uid && !isStaff) {
      throw new HttpsError('permission-denied', 'Access denied');
    }
    snap = await admin.firestore().doc(docPath).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Document not found');
  } else {
    const ALLOWED = ['users', 'queue', 'consultations', 'prescriptions', 'appointments', 'medical_records'];
    if (!ALLOWED.includes(collection)) throw new HttpsError('invalid-argument', 'Unknown collection');
    snap = await admin.firestore().collection(collection).doc(docId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Document not found');
    const docData = snap.data();
    const isOwner = docData.patientId === req.auth.uid
      || docData.uid === req.auth.uid
      || docId === req.auth.uid; // users/{uid} — doc ID is the owner's UID
    const callerSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
    const isStaff = ['nurse', 'doctor', 'staff'].includes(callerSnap.data()?.role);
    if (!isOwner && !isStaff) throw new HttpsError('permission-denied', 'Access denied');
  }

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const result = { ...snap.data() };

  for (const f of (fields || [])) {
    if (result[f] && isEncrypted(result[f])) {
      try { result[f] = decrypt(result[f], key); } catch (_) {}
    }
  }

  return result;
});



