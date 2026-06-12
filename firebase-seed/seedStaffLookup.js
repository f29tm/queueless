const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function seedStaffLookup() {
  const snapshot = await db.collection("users")
    .where("role", "in", ["nurse", "doctor", "staff"])
    .get();

  if (snapshot.empty) {
    console.log("No staff users found.");
    return;
  }

  for (const doc of snapshot.docs) {
    const { staffId, email } = doc.data();
    if (!staffId || !email) continue;
    await db.collection("staff_lookup").doc(staffId).set({ email });
    console.log(`staff_lookup: ${staffId} → ${email}`);
  }

  console.log("Done.");
}

seedStaffLookup().catch(console.error);
