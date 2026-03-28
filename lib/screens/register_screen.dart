import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Prefilled details for testing:
  // final TextEditingController nationalIdController = TextEditingController(text: "123456789012345");
  // final TextEditingController firstNameController = TextEditingController(text: "Fatima");
  // final TextEditingController middleNameController = TextEditingController(text: "M");
  // final TextEditingController lastNameController = TextEditingController(text: "Test");
  // final TextEditingController emailController = TextEditingController(text: "ftm3az@gmail.com");
  // final TextEditingController phoneController = TextEditingController(text: "0505166438");
  // final TextEditingController dobController = TextEditingController(text: "01/01/2000");
  // final TextEditingController passwordController = TextEditingController(text: "Strong@Pass1");
  // final TextEditingController confirmPasswordController = TextEditingController(text: "Strong@Pass1");
  // String? selectedGender = "Female";
  // String? selectedNationality = "Lebanon";

  final TextEditingController nationalIdController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? selectedGender;
  String? selectedNationality;

  final List<String> genders = ["Male", "Female"];
  final List<String> nationalities = [
    "United Arab Emirates",
    "Saudi Arabia",
    "Qatar",
    "Kuwait",
    "Bahrain",
    "Oman",
    "Jordan",
    "Lebanon",
    "Syria",
    "Iraq",
    "Palestine",
    "Egypt",
    "Sudan",
    "Morocco",
    "Algeria",
    "Tunisia",
    "Yemen",
    "India",
    "Pakistan",
    "Bangladesh",
    "Philippines",
    "Sri Lanka",
    "Nepal",
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
    if (firstNameController.text.isEmpty ||
        middleNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        dobController.text.isEmpty ||
        selectedGender == null ||
        selectedNationality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (!RegExp(r"^\d{15}$").hasMatch(nationalIdController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("National ID must be 15 digits")),
      );
      return;
    }

    if (!RegExp(
      r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    ).hasMatch(emailController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid email")));
      return;
    }

    if (!RegExp(r"^05\d{8}$").hasMatch(phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid UAE number (e.g., 0501234567)"),
        ),
      );
      return;
    }

    if (!isStrongPassword(passwordController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Weak password")));
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    // Prepare user data
    Map<String, dynamic> userData = {
      "nationalID": nationalIdController.text,
      "firstName": firstNameController.text,
      "middleName": middleNameController.text,
      "lastName": lastNameController.text,
      "phone": phoneController.text,
      "dob": dobController.text,
      "gender": selectedGender,
      "nationality": selectedNationality,
      "role": "patient",
    };

    // Use AuthProvider to sign up
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signUp(
        email: emailController.text,
        password: passwordController.text,
        userData: userData,
      );

      // Send email verification
      await authProvider.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Registration successful! Please check your email for verification.",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: ${e.toString()}")),
      );
    }
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: const InputDecoration(
                labelText: "National ID (15 digits)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: firstNameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ],
              decoration: const InputDecoration(
                labelText: "First Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: middleNameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ],
              decoration: const InputDecoration(
                labelText: "Middle Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ],
              decoration: const InputDecoration(
                labelText: "Last Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (val) {
                if (val.length == 1 && val != "0") {
                  phoneController.text = "0";
                  phoneController.selection = TextSelection.fromPosition(
                    const TextPosition(offset: 1),
                  );
                } else if (val.length == 2 && val != "05") {
                  phoneController.text = "05";
                  phoneController.selection = TextSelection.fromPosition(
                    const TextPosition(offset: 2),
                  );
                }
              },
              decoration: const InputDecoration(
                labelText: "Phone (UAE, e.g. 05x)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dobController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: "Date of Birth",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedGender,
              items: genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) => setState(() => selectedGender = val),
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedNationality,
              items: nationalities
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (val) => setState(() => selectedNationality = val),
              decoration: const InputDecoration(
                labelText: "Nationality",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: validateAllFields,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
