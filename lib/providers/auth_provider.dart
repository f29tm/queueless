
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;        // Firebase user (patients only)
  String? userRole;         // "patient" or "staff"
  String? userName;         // full name for both

  AuthProvider() {
    _auth.authStateChanges().listen((user) async {
      currentUser = user;

      // ✅ If Firebase user logged in → load patient data
      if (user != null) {
        await _loadUserData();
      } else {
        userRole = null;
        userName = null;
      }

      notifyListeners();
    });
  }

  // ✅ PATIENT SIGN-UP WITH DETAILS
  Future<String?> signUpWithDetails({
    required String name,
    required String email,
    required String password,
    required String phone,
    required Map<String, dynamic> extraData,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = cred.user;

      Map<String, dynamic> userData = {
        "name": name,
        "email": email,
        "phone": phone,
        "role": "patient",
        "emailVerified": false,
        "createdAt": Timestamp.now(),
      };

      userData.addAll(extraData);

      await _firestore.collection("users").doc(currentUser!.uid).set(userData);

      await currentUser!.sendEmailVerification();
      await _loadUserData();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ PATIENT LOGIN USING FIREBASE AUTH
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = cred.user;

      await currentUser!.reload();
      if (!currentUser!.emailVerified) {
        await _auth.signOut();
        currentUser = null;
        return "Please verify your email before logging in.";
      }

      await _syncEmailVerification();
      await _loadUserData();
      return null;

    } catch (e) {
      return e.toString();
    }
  }

  // ✅ STAFF LOGIN USING STAFF ID + PASSWORD (FIRESTORE ONLY)
  Future<String?> staffSignIn({
    required String staffId,
    required String password,
  }) async {
    try {
      // Find staff by staffId
      final query = await _firestore
          .collection("users")
          .where("staffId", isEqualTo: staffId)
          .where("role", isEqualTo: "staff")
          .get();

      if (query.docs.isEmpty) {
        return "Staff ID not found.";
      }

      final doc = query.docs.first;
      final data = doc.data();

      // Password check (plain text for now)
      if (data["password"] != password) {
        return "Incorrect password.";
      }

      // ✅ Staff login success → NO FirebaseAuth
      currentUser = null;
      userRole = "staff";
      userName = data["fullName"];

      notifyListeners();
      return null;

    } catch (e) {
      return e.toString();
    }
  }

  // ✅ Load patient data (Firebase users only)
  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    final doc =
        await _firestore.collection("users").doc(currentUser!.uid).get();

    userRole = doc.data()?["role"];
    userName = doc.data()?["name"];
  }

  // ✅ Sync patient email verification
  Future<void> _syncEmailVerification() async {
    if (currentUser == null) return;

    await currentUser!.reload();
    bool verified = currentUser!.emailVerified;

    await _firestore.collection("users").doc(currentUser!.uid).update({
      "emailVerified": verified,
    });
  }

  // ✅ RESEND
  Future<void> resendEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  // ✅ LOGOUT (works for both patient + staff)
  Future<void> signOut() async {
    await _auth.signOut(); // does nothing if staff is logged in
    currentUser = null;
    userRole = null;
    userName = null;
    notifyListeners();
  }
}