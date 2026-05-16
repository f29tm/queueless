const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const nurses = [
  {
    staffId: "NUR1001",
    name: "Nurse Sara Ahmed",
    email: "queueless.nurse+test1001@gmail.com",
    password: "Nurse123",
    hospital: "NMC Royal Hospital Khalifa City, Abu Dhabi",
    role: "nurse",
  },
  {
    staffId: "NUR1002",
    name: "Nurse Mariam Hassan",
    email: "queueless.nurse+test1002@gmail.com",
    password: "Nurse123",
    hospital: "NMC Royal Hospital Khalifa City, Abu Dhabi",
    role: "nurse",
  },
  {
    staffId: "NUR1003",
    name: "Nurse Reem Ali",
    email: "queueless.nurse+test1003@gmail.com",
    password: "Nurse123",
    hospital: "NMC Royal Hospital Khalifa City, Abu Dhabi",
    role: "nurse",
  },
  {
    staffId: "NUR1004",
    name: "Nurse Huda Saeed",
    email: "queueless.nurse+test1004@gmail.com",
    password: "Nurse123",
    hospital: "NMC Royal Hospital Khalifa City, Abu Dhabi",
    role: "nurse",
  },
  {
    staffId: "NUR1005",
    name: "Nurse Aisha Khalid",
    email: "queueless.nurse+test1005@gmail.com",
    password: "Nurse123",
    hospital: "NMC Royal Hospital Khalifa City, Abu Dhabi",
    role: "nurse",
  },
];

async function seedNurses() {
  for (const nurse of nurses) {
    let userRecord;

    try {
      userRecord = await admin.auth().createUser({
        email: nurse.email,
        password: nurse.password,
        displayName: nurse.name,
      });

      console.log(`Auth created: ${nurse.name}`);
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        userRecord = await admin.auth().getUserByEmail(nurse.email);
        console.log(`Auth already exists: ${nurse.name}`);
      } else {
        throw error;
      }
    }

    await db.collection("users").doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        staffId: nurse.staffId,
        name: nurse.name,
        email: nurse.email,
        hospital: nurse.hospital,
        role: nurse.role,
        status: "active",
        updatedAt: new Date(),
      },
      { merge: true }
    );

    console.log(`Firestore updated: ${nurse.staffId} - ${nurse.name}`);
  }
}

seedNurses().catch(console.error);