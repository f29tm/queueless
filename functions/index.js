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

  await admin.firestore().collection('queue').doc(docId).set(encrypted, { merge: true });
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

// ─── getDecryptedData — read + decrypt for authorized caller ─────────────────
exports.getDecryptedData = onCall({ secrets: [ENCRYPTION_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { collection, docId, fields } = req.data;

  const ALLOWED = ['users', 'queue', 'consultations', 'prescriptions'];
  if (!ALLOWED.includes(collection)) throw new HttpsError('invalid-argument', 'Unknown collection');

  const snap = await admin.firestore().collection(collection).doc(docId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Document not found');

  const docData = snap.data();
  const isOwner = docData.patientId === req.auth.uid || docData.uid === req.auth.uid;
  const userSnap = await admin.firestore().collection('users').doc(req.auth.uid).get();
  const isStaff = ['nurse', 'doctor', 'staff'].includes(userSnap.data()?.role);

  if (!isOwner && !isStaff) throw new HttpsError('permission-denied', 'Access denied');

  const key = Buffer.from(ENCRYPTION_KEY.value(), 'base64');
  const result = { ...docData };

  for (const f of (fields || [])) {
    if (result[f] && isEncrypted(result[f])) {
      try { result[f] = decrypt(result[f], key); } catch (_) { /* not encrypted */ }
    }
  }

  return result;
});
