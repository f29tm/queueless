import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';


class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;        
  String? userRole;         
  String? userName;         

  AuthProvider() {
    _auth.authStateChanges().listen((user) async {
      currentUser = user;

      if (user != null) {
        await _loadUserData();
      } else {
        userRole = null;
        userName = null;
      }

      notifyListeners();
    });
  }

  // ✅ PATIENT SIGN-UP
  Future<String?> signUpWithDetails({
    required String name,
    required String email,
    required String password,
    required String phone,
    required Map<String, dynamic> extraData,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      currentUser = cred.user;

      Map<String, dynamic> userData = {
        "uid": currentUser!.uid,
        "name": name,
        "email": email.trim(),
        "phone": phone,
        "role": "patient",
        "emailVerified": false,
        "createdAt": Timestamp.now(),
      };

      userData.addAll(extraData);

      await _firestore.collection("users").doc(currentUser!.uid).set(userData);

      await currentUser!.sendEmailVerification();

      await _auth.signOut();
      currentUser = null;
      userRole = null;
      userName = null;

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ PATIENT LOGIN
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      currentUser = cred.user;
      await currentUser!.reload();
      currentUser = _auth.currentUser;

      if (currentUser != null && !currentUser!.emailVerified) {
        await _auth.signOut();
        currentUser = null;
        userRole = null;
        userName = null;
        return "Please verify your email before logging in.";
      }

      await _syncEmailVerification();
      await _loadUserData();

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ ✅ UPDATED STAFF LOGIN (FIREBASE AUTH)
  Future<String?> staffSignIn({
    required String staffId,
    required String password,
  }) async {
    try {
      // ✅ Step 1: Find staff in Firestore
      final query = await _firestore
          .collection("users")
          .where("staffId", isEqualTo: staffId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return "Staff ID not found.";
      }

      // ✅ Step 2: Get email
      final data = query.docs.first.data();
      final email = data["email"];

      // ✅ Step 3: Firebase login
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = cred.user;

      // ✅ Step 4: Load role + name
      await _loadUserData();

      return null;
    } catch (e) {
      return "Invalid Staff ID or password.";
    }
  }

  // ✅ LOAD USER DATA (works for both patient + staff)
  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    final doc = await _firestore.collection("users").doc(currentUser!.uid).get();

    userRole = doc.data()?["role"];

    // ✅ Handle both patient & staff naming
    userName = doc.data()?["name"] ?? doc.data()?["fullName"];
  }

  // ✅ SYNC EMAIL VERIFIED (patients)
  Future<void> _syncEmailVerification() async {
    if (currentUser == null) return;

    await currentUser!.reload();
    currentUser = _auth.currentUser;

    await _firestore.collection("users").doc(currentUser!.uid).update({
      "emailVerified": currentUser!.emailVerified,
    });
  }

  // ✅ RESEND EMAIL
  Future<void> resendEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  // ✅ LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
    await _auth.signOut();
    currentUser = null;
    userRole = null;
    userName = null;
    notifyListeners();
  }

  // ✅ RESET PASSWORD (PATIENT + STAFF BOTH USE THIS)
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ✅ STAFF RESET (validate ID → then send email)
  Future<String?> staffResetPassword({
    required String staffId,
    required String email,
  }) async {
    try {
      final query = await _firestore
          .collection("users")
          .where("staffId", isEqualTo: staffId)
          .where("role", isEqualTo: "staff")
          .get();

      if (query.docs.isEmpty) {
        return "Staff ID not found.";
      }

      final data = query.docs.first.data();

      if (data["email"] != email) {
        return "Email does not match this Staff ID.";
      }

      await _auth.sendPasswordResetEmail(email: email);

      return null;

    } catch (e) {
      return e.toString();
    }
  }
  String hashData(String input) {
  final bytes = utf8.encode(input);
  final hash = sha256.convert(bytes);
  return hash.toString();
}
}