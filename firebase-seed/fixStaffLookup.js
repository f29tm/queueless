const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Authoritative staffId → email mapping from seed scripts
const staffLookup = {
  NUR1001: "queueless.nurse+test1001@gmail.com",
  NUR1002: "queueless.nurse+test1002@gmail.com",
  NUR1003: "queueless.nurse+test1003@gmail.com",
  NUR1004: "queueless.nurse+test1004@gmail.com",
  NUR1005: "queueless.nurse+test1005@gmail.com",
  DOC1001: "queueless.staff+test1001@gmail.com",
  DOC1002: "queueless.staff+test1002@gmail.com",
  DOC1003: "queueless.staff+test1003@gmail.com",
  DOC1004: "queueless.staff+test1004@gmail.com",
  DOC1005: "queueless.staff+test1005@gmail.com",
  DOC1006: "queueless.staff+test1006@gmail.com",
  DOC1007: "queueless.staff+test1007@gmail.com",
  DOC1008: "queueless.staff+test1008@gmail.com",
  DOC1009: "queueless.staff+test1009@gmail.com",
  DOC1010: "queueless.staff+test1010@gmail.com",
  DOC1011: "queueless.staff+test1011@gmail.com",
  DOC1012: "queueless.staff+test1012@gmail.com",
  DOC1013: "queueless.staff+test1013@gmail.com",
  DOC1014: "queueless.staff+test1014@gmail.com",
  DOC1015: "queueless.staff+test1015@gmail.com",
  DOC1016: "queueless.staff+test1016@gmail.com",
  DOC1017: "queueless.staff+test1017@gmail.com",
  DOC1018: "queueless.staff+test1018@gmail.com",
  DOC1019: "queueless.staff+test1019@gmail.com",
  DOC1020: "queueless.staff+test1020@gmail.com",
  DOC1021: "queueless.staff+test1021@gmail.com",
  DOC1022: "queueless.staff+test1022@gmail.com",
  DOC1023: "queueless.staff+test1023@gmail.com",
  DOC1024: "queueless.staff+test1024@gmail.com",
  DOC1025: "queueless.staff+test1025@gmail.com",
  DOC1026: "queueless.staff+test1026@gmail.com",
};

async function fix() {
  for (const [staffId, email] of Object.entries(staffLookup)) {
    await db.collection("staff_lookup").doc(staffId).set({ email });
    console.log(`Fixed: ${staffId} → ${email}`);
  }
  console.log("Done.");
}

fix().catch(console.error);
