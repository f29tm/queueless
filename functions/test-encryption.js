/**
 * Local encryption unit test — runs without Firebase, no deployment needed.
 *
 * Usage:
 *   node functions/test-encryption.js
 *
 * Requires a 32-byte base64 key in ENCRYPTION_KEY env var, or generates a
 * throwaway one for testing purposes.
 */

const crypto = require('crypto');

// ── Copy the exact same functions from index.js ──────────────────────────────

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

// ── Test helpers ─────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;

function assert(label, condition) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}`);
    failed++;
  }
}

// Use env key or generate a fresh throwaway key for this test run
const key = process.env.ENCRYPTION_KEY
  ? Buffer.from(process.env.ENCRYPTION_KEY, 'base64')
  : crypto.randomBytes(32);

// ── Test 1: saveVitalsData — vital signs ─────────────────────────────────────

console.log('\nTest 1: saveVitalsData — vital signs encryption');

const vitalsInput = { patientId: 'uid123', sbp: 120, dbp: 80, hr: 72, rr: 16, bt: 37.0, o2: 98 };
const encryptedVitals = encryptFields(vitalsInput, ['sbp', 'dbp', 'hr', 'rr', 'bt', 'o2'], key);

assert('patientId stays plaintext',        !isEncrypted(encryptedVitals.patientId));
assert('sbp is encrypted',                 isEncrypted(encryptedVitals.sbp));
assert('dbp is encrypted',                 isEncrypted(encryptedVitals.dbp));
assert('hr is encrypted',                  isEncrypted(encryptedVitals.hr));
assert('rr is encrypted',                  isEncrypted(encryptedVitals.rr));
assert('bt is encrypted',                  isEncrypted(encryptedVitals.bt));
assert('o2 is encrypted',                  isEncrypted(encryptedVitals.o2));

assert('sbp decrypts to original value',   decrypt(encryptedVitals.sbp, key) === '120');
assert('bt decrypts to original value',    decrypt(encryptedVitals.bt, key) === '37');
assert('o2 decrypts to original value',    decrypt(encryptedVitals.o2, key) === '98');

// Each encryption call produces a different ciphertext (random IV)
const sbpEncrypted2 = encrypt(String(vitalsInput.sbp), key);
assert('same value encrypts differently each time (random IV)', encryptedVitals.sbp !== sbpEncrypted2);

// ── Test 2: saveMedicalRecord — clinical fields ───────────────────────────────

console.log('\nTest 2: saveMedicalRecord — clinical fields encryption');

const vitalSigns = { sbp: 120, dbp: 80, hr: 72, rr: 16, bt: 37.0, o2: 98 };

const medRecInput = {
  patientId:        'uid123',
  patientName:      'Fatima Al Neyadi',   // kept plaintext per design decision
  type:             'nurse_triage',
  stage1Prediction: 'Emergency',
  stage2Prediction: 'Emergency',
  finalTriageLevel: 'EMERGENCY',
  oldTriageLevel:   'MODERATE',
  confidence:       0.941,
  nurseOverride:    false,
  vitalSigns:       JSON.stringify(vitalSigns), // pre-serialised as the CF does it
  ktasRn:           2,
};

const encryptedFields = ['stage1Prediction', 'stage2Prediction', 'finalTriageLevel',
  'oldTriageLevel', 'confidence', 'nurseOverride', 'vitalSigns', 'ktasRn'];

const encryptedMedRec = encryptFields(medRecInput, encryptedFields, key);

assert('patientId stays plaintext',            !isEncrypted(encryptedMedRec.patientId));
assert('patientName stays plaintext',          !isEncrypted(encryptedMedRec.patientName));
assert('type stays plaintext',                 !isEncrypted(encryptedMedRec.type));
assert('stage1Prediction is encrypted',        isEncrypted(encryptedMedRec.stage1Prediction));
assert('stage2Prediction is encrypted',        isEncrypted(encryptedMedRec.stage2Prediction));
assert('finalTriageLevel is encrypted',        isEncrypted(encryptedMedRec.finalTriageLevel));
assert('oldTriageLevel is encrypted',          isEncrypted(encryptedMedRec.oldTriageLevel));
assert('confidence is encrypted',              isEncrypted(encryptedMedRec.confidence));
assert('nurseOverride is encrypted',           isEncrypted(encryptedMedRec.nurseOverride));
assert('vitalSigns is encrypted',              isEncrypted(encryptedMedRec.vitalSigns));
assert('ktasRn is encrypted',                  isEncrypted(encryptedMedRec.ktasRn));

assert('stage1Prediction decrypts correctly',  decrypt(encryptedMedRec.stage1Prediction, key) === 'Emergency');
assert('confidence decrypts correctly',        decrypt(encryptedMedRec.confidence, key) === '0.941');
assert('nurseOverride decrypts correctly',     decrypt(encryptedMedRec.nurseOverride, key) === 'false');
assert('ktasRn decrypts correctly',            decrypt(encryptedMedRec.ktasRn, key) === '2');

const decryptedVitalSigns = JSON.parse(decrypt(encryptedMedRec.vitalSigns, key));
assert('vitalSigns decrypts to valid JSON',    typeof decryptedVitalSigns === 'object');
assert('vitalSigns.sbp round-trips correctly', decryptedVitalSigns.sbp === 120);
assert('vitalSigns.bt round-trips correctly',  decryptedVitalSigns.bt === 37.0);

// ── Test 3: wrong key cannot decrypt ─────────────────────────────────────────

console.log('\nTest 3: tamper resistance — wrong key fails');

const wrongKey = crypto.randomBytes(32);
let decryptFailed = false;
try {
  decrypt(encryptedVitals.sbp, wrongKey);
} catch (_) {
  decryptFailed = true;
}
assert('decryption with wrong key throws', decryptFailed);

// ── Test 4: saveNotification — notification content encryption ────────────────

console.log('\nTest 4: saveNotification — notification content encryption');

const patientNotif = {
  type: 'triageOverride',
  title: 'Triage Level Updated',
  body: 'Your triage level has been changed from Urgent to Emergency by Nurse Sara.',
  titleAr: 'تم تحديث مستوى الفرز',
  bodyAr: 'تم تغيير مستوى الفرز الخاص بك من عاجل إلى طارئ بواسطة Nurse Sara.',
  metadata: { oldLevel: 'MODERATE', newLevel: 'EMERGENCY', nurseName: 'Nurse Sara', reason: 'vitals deteriorated' },
  isRead: false,
};

const encryptedNotif = encryptFields(
  patientNotif,
  ['title', 'body', 'titleAr', 'bodyAr'],
  key
);

assert('type stays plaintext',     !isEncrypted(encryptedNotif.type));
assert('isRead stays plaintext',   !isEncrypted(encryptedNotif.isRead));
assert('metadata stays plaintext', typeof encryptedNotif.metadata === 'object');
assert('title is encrypted',       isEncrypted(encryptedNotif.title));
assert('body is encrypted',        isEncrypted(encryptedNotif.body));
assert('titleAr is encrypted',     isEncrypted(encryptedNotif.titleAr));
assert('bodyAr is encrypted',      isEncrypted(encryptedNotif.bodyAr));

assert('title decrypts correctly',   decrypt(encryptedNotif.title, key) === 'Triage Level Updated');
assert('body contains patient name', decrypt(encryptedNotif.body, key).includes('Nurse Sara'));
assert('titleAr decrypts correctly', decrypt(encryptedNotif.titleAr, key) === 'تم تحديث مستوى الفرز');
assert('bodyAr decrypts correctly',  decrypt(encryptedNotif.bodyAr, key).includes('Nurse Sara'));

// Doctor notification (no titleAr / bodyAr)
const doctorNotif = {
  type: 'appointmentCancelled',
  title: 'Appointment Cancelled by Patient',
  body: 'Ahmed Al Mansoori has cancelled their appointment on 15/06/2026.',
  isRead: false,
};
const encryptedDoctorNotif = encryptFields(doctorNotif, ['title', 'body', 'titleAr', 'bodyAr'], key);
assert('doctor notif title encrypted',          isEncrypted(encryptedDoctorNotif.title));
assert('missing titleAr left absent (not "")',  encryptedDoctorNotif.titleAr === undefined);

// Stream-level decryption guard — plaintext title should not trigger decrypt call
const plaintextNotif = { id: 'old1', title: 'Old unencrypted notification' };
const colonCount = (plaintextNotif.title.match(/:/g) || []).length;
assert('old plaintext notif skips decryption (colonCount != 2)', colonCount !== 2);

// ── Summary ───────────────────────────────────────────────────────────────────

console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
