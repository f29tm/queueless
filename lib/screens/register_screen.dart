
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ✅ Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? selectedGender;
  DateTime? selectedDate;

  bool obscurePass = true;
  bool obscureConfirm = true;

  final List<String> genders = ["Male", "Female"];

  final List<String> allCountries = [
    "United Arab Emirates",
    "Saudi Arabia",
    "Kuwait",
    "Qatar",
    "Bahrain",
    "Oman",
    "Egypt",
    "Jordan",
    "Lebanon",
    "Syria",
    "Iraq",
    "India",
    "Pakistan",
    "Bangladesh",
    "Philippines",
    "United Kingdom",
    "United States",
    "Canada",
    "Australia",
    "Germany",
    "France",
  ];

  bool isStrongPassword(String pwd) {
    return pwd.length >= 8 &&
        RegExp(r"[A-Z]").hasMatch(pwd) &&
        RegExp(r"[a-z]").hasMatch(pwd) &&
        RegExp(r"[0-9]").hasMatch(pwd) &&
        RegExp(r'[!@#\$%\^&\*\(\)\.\?\:"\{\}\|<>]').hasMatch(pwd);
  }

  Future<void> _selectDOB() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ✅ REGISTER with full validation
  void registerUser() async {
    // ✅ FULL NAME
    if (fullNameController.text.trim().isEmpty) {
      _showError("Full name is required.");
      return;
    }
    if (!fullNameController.text.trim().contains(" ")) {
      _showError("Enter full name (first & last).");
      return;
    }

    // ✅ EMIRATES ID
    final emiratesId = nationalIdController.text.trim();
    final emiratesIdRegex = RegExp(r"^784-\d{4}-\d{7}-\d{1}$");
    if (!emiratesIdRegex.hasMatch(emiratesId)) {
      _showError("Enter a valid Emirates ID (784-YYYY-XXXXXXX-X).");
      return;
    }

    // ✅ DOB
    if (dobController.text.trim().isEmpty) {
      _showError("Date of Birth is required.");
      return;
    }

    // ✅ NATIONALITY
    if (nationalityController.text.trim().isEmpty) {
      _showError("Please select your nationality.");
      return;
    }

    // ✅ GENDER
    if (selectedGender == null) {
      _showError("Please select your gender.");
      return;
    }

    // ✅ PHONE (UAE FORMAT)
    final phone = phoneController.text.trim();
    final phoneRegex = RegExp(r"^05\d{8}$");
    if (!phoneRegex.hasMatch(phone)) {
      _showError("Enter valid UAE phone (05XXXXXXXX).");
      return;
    }

    // ✅ EMAIL
    final email = emailController.text.trim();
    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) {
      _showError("Enter a valid email address.");
      return;
    }

    // ✅ PASSWORD
    if (!isStrongPassword(passwordController.text)) {
      _showError(
          "Weak password — use A‑Z, a‑z, numbers & special characters.");
      return;
    }

    // ✅ CONFIRM PASSWORD
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      _showError("Passwords do not match.");
      return;
    }

    // ✅ EXTRA PATIENT DATA
    final extraData = {
      "fullName": fullNameController.text.trim(),
      "nationalId": emiratesId,
      "dob": dobController.text.trim(),
      "nationality": nationalityController.text.trim(),
      "gender": selectedGender,
      "phone": phone,
      "role": "patient",
    };

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final error = await auth.signUpWithDetails(
      name: fullNameController.text.trim(),
      email: email,
      password: passwordController.text.trim(),
      phone: phone,
      extraData: extraData,
    );

    if (error != null) {
      _showError(error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account created! Please verify your email."),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ HEADER
            Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF009688), Color(0xFF00796B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      "assets/images/logo.png",
                      width: 70,
                      height: 70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Create Your Account",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ✅ FORM CONTENT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  _input(fullNameController, "Full Name", Icons.person,
                      "e.g. Meriem Bettayeb"),
                  const SizedBox(height: 16),

                  _input(nationalIdController, "National ID", Icons.badge,
                      "e.g. 784-YYYY-XXXXXXX-X"),
                  const SizedBox(height: 16),

                  _dobField(),
                  const SizedBox(height: 16),

                  _searchableDropdown(
                    label: "Nationality",
                    value: nationalityController.text.isEmpty
                        ? null
                        : nationalityController.text,
                    icon: Icons.flag,
                    items: allCountries,
                    onChanged: (v) {
                      setState(() {
                        nationalityController.text = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _dropdown(
                    label: "Gender",
                    value: selectedGender,
                    icon: Icons.person_outline,
                    items: genders,
                    onChanged: (v) => setState(() => selectedGender = v),
                  ),
                  const SizedBox(height: 16),

                  _input(phoneController, "Phone Number", Icons.phone,
                      "e.g. 0501234567"),
                  const SizedBox(height: 16),

                  _input(emailController, "Email", Icons.email,
                      "e.g. example@gmail.com"),
                  const SizedBox(height: 16),

                  _passwordField(passwordController, "Password", "Strong@Pass1",
                      obscurePass, () {
                    setState(() => obscurePass = !obscurePass);
                  }),
                  const SizedBox(height: 16),

                  _passwordField(confirmPasswordController, "Confirm Password",
                      "Repeat password", obscureConfirm, () {
                    setState(() => obscureConfirm = !obscureConfirm);
                  }),
                  const SizedBox(height: 24),

                  // ✅ BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Create Account",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text(
                          "Sign In",
                          style: TextStyle(
                            color: Color(0xFF009688),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ INPUT FIELD
  Widget _input(
      TextEditingController c, String label, IconData icon, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Color(0xFF009688)),
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ✅ PASSWORD FIELD
  Widget _passwordField(TextEditingController c, String label, String hint,
      bool obscure, VoidCallback toggle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF009688)),
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon:
                Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  // ✅ DOB FIELD (FIXED)
  Widget _dobField() {
    return GestureDetector(
      onTap: _selectDOB,
      child: AbsorbPointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: dobController,
            decoration: const InputDecoration(
              prefixIcon:
                  Icon(Icons.calendar_today, color: Color(0xFF009688)),
              labelText: "Date of Birth",
              hintText: "DD/MM/YYYY",
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ GENDER DROPDOWN
  Widget _dropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Color(0xFF009688)),
          border: InputBorder.none,
          labelText: label,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ✅ SEARCHABLE DROPDOWN
  Widget _searchableDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return StatefulBuilder(
      builder: (context, setStateSB) {
        List<String> filtered = List.from(items);
        TextEditingController search = TextEditingController();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: StatefulBuilder(
                          builder: (context, setSheet) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: search,
                                  decoration: const InputDecoration(
                                    hintText: "Search nationality",
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    setSheet(() {
                                      filtered = items
                                          .where((e) => e
                                              .toLowerCase()
                                              .contains(v.toLowerCase()))
                                          .toList();
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 300,
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) {
                                      return ListTile(
                                        title: Text(filtered[i]),
                                        onTap: () {
                                          onChanged(filtered[i]);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFF009688)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value ?? "Select nationality",
                        style: TextStyle(
                          color: value == null ? Colors.grey : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down)
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}