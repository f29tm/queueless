import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<String?> staffSignIn({
    required String staffId,
    required String password,
  }) async {
    try {
      final id = staffId.trim();

      final query = await _firestore
          .collection("users")
          .where("staffId", isEqualTo: id)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return "Staff ID not found.";
      }

      final data = query.docs.first.data();

      if (data["role"] != "doctor" && data["role"] != "staff") {
        return "This account is not authorized.";
      }

      final String email = data["email"];

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      currentUser = cred.user;
      await currentUser!.reload();
      currentUser = _auth.currentUser;

      if (currentUser != null && !currentUser!.emailVerified) {
        await currentUser!.sendEmailVerification();

        await _auth.signOut();
        currentUser = null;
        userRole = null;
        userName = null;

        notifyListeners();

        return "Verification email sent to $email. Check Gmail inbox, spam, and updates.";
      }

      userRole = data["role"];
      userName = data["name"] ?? data["fullName"];

      await _firestore.collection("users").doc(currentUser!.uid).update({
        "emailVerified": true,
      });

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    final doc = await _firestore.collection("users").doc(currentUser!.uid).get();

    userRole = doc.data()?["role"];
    userName = doc.data()?["name"] ?? doc.data()?["fullName"];
  }

  Future<void> _syncEmailVerification() async {
    if (currentUser == null) return;

    await currentUser!.reload();
    currentUser = _auth.currentUser;

    await _firestore.collection("users").doc(currentUser!.uid).update({
      "emailVerified": currentUser!.emailVerified,
    });
  }

  Future<void> resendEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    currentUser = null;
    userRole = null;
    userName = null;
    notifyListeners();
  }
}