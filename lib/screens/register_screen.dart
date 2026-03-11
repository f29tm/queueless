import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../services/email_sender.dart';
import 'verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nationalIdController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? selectedGender;
  String? selectedNationality;

  final FirebaseFirestore db = FirebaseFirestore.instance;

  final List<String> genders = ["Male", "Female"];
  final List<String> nationalities = [
    "United Arab Emirates", "Saudi Arabia", "Qatar", "Kuwait", "Bahrain", "Oman",
    "Jordan", "Lebanon", "Syria", "Iraq", "Palestine", "Egypt", "Sudan", "Morocco",
    "Algeria", "Tunisia", "Yemen", "India", "Pakistan", "Bangladesh", "Philippines",
    "Sri Lanka", "Nepal"
  ];

  DateTime? selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dobController.text = DateFormat('dd/MM/yyyy').format(selectedDate!);
      });
    }
  }

  bool isStrongPassword(String pwd) {
    return pwd.length >= 8 &&
        RegExp(r".*[A-Z].*").hasMatch(pwd) &&
        RegExp(r".*[a-z].*").hasMatch(pwd) &&
        RegExp(r".*\d.*").hasMatch(pwd) &&
        RegExp(r".*[@#\$%^&+=!*\.?].*").hasMatch(pwd);
  }

  String maskEmail(String email) {
    int index = email.indexOf("@");
    if (index <= 2) {
      return "\${email[0]}*****\${email.substring(index)}";
    }
    return "\${email.substring(0, 2)}*****\${email.substring(index)}";
  }

  void validateAllFields() async {
    // Sanitize inputs
    String nationalId = nationalIdController.text.replaceAll(RegExp(r'\s|-'), '');
    String phone = phoneController.text.replaceAll(RegExp(r'\s|-'), '');
    
    if (firstNameController.text.isEmpty ||
        middleNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        dobController.text.isEmpty ||
        selectedGender == null ||
        selectedNationality == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    if (!RegExp(r"^\d{15}$").hasMatch(nationalId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("National ID must be exactly 15 digits")));
      return;
    }

    if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid email")));
      return;
    }

    if (!RegExp(r"^05\d{8}$").hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid UAE number (e.g., 0501234567)")));
      return;
    }

    if (!isStrongPassword(passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weak password")));
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    // Check unique
    final emailQuery = await db.collection("users").where("email", isEqualTo: emailController.text).get();
    if (!mounted) return;
    if (emailQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email already exists")));
      return;
    }

    final phoneQuery = await db.collection("users").where("phone", isEqualTo: phoneController.text).get();
    if (phoneQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone already exists")));
      return;
    }

    final nationalIdQuery = await db.collection("users").where("nationalID", isEqualTo: nationalIdController.text).get();
    if (nationalIdQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("National ID already exists")));
      return;
    }

    saveUserToDatabase(const Uuid().v4(), nationalId, phone);
  }

  void saveUserToDatabase(String uid, String sanitizedNationalId, String sanitizedPhone) {
    String email = emailController.text;
    String masked = maskEmail(email);
    String otp = (Random().nextInt(900000) + 100000).toString();
    int otpCreatedAt = DateTime.now().millisecondsSinceEpoch;
    int expireTime = otpCreatedAt + 120000;

    Map<String, dynamic> user = {
      "nationalID": sanitizedNationalId,
      "firstName": firstNameController.text,
      "middleName": middleNameController.text,
      "lastName": lastNameController.text,
      "email": email,
      "phone": sanitizedPhone,
      "dob": dobController.text,
      "gender": selectedGender,
      "nationality": selectedNationality,
      "password": passwordController.text,
      "role": "patient",
      "otpCreatedAt": otpCreatedAt,
    };

    db.collection("users").doc(uid).set(user).then((_) {
      EmailSender.sendEmail(
        toEmail: email,
        subject: "Your Registration Verification Code",
        otp: "Your OTP is: $otp",
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            otp: otp,
            maskedEmail: masked,
            email: email,
            method: 'email',
            role: 'patient',
            expireTime: expireTime,
            isReset: false,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: nationalIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
              decoration: const InputDecoration(labelText: "National ID (15 digits)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: firstNameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
              decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: middleNameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
              decoration: const InputDecoration(labelText: "Middle Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
              decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (val) {
                if (val.length == 1 && val != "0") {
                  phoneController.text = "0";
                  phoneController.selection = TextSelection.fromPosition(const TextPosition(offset: 1));
                } else if (val.length == 2 && val != "05") {
                  phoneController.text = "05";
                  phoneController.selection = TextSelection.fromPosition(const TextPosition(offset: 2));
                }
              },
              decoration: const InputDecoration(labelText: "Phone (UAE, e.g. 05x)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dobController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(labelText: "Date of Birth", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGender,
              items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => selectedGender = val),
              decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedNationality,
              items: nationalities.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (val) => setState(() => selectedNationality = val),
              decoration: const InputDecoration(labelText: "Nationality", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: validateAllFields,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("Create Account"),
            )
          ],
        ),
      ),
    );
  }
}
