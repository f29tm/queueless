
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _fullNameController       = TextEditingController();
  final _nationalIdController     = TextEditingController();
  final _dobController            = TextEditingController();
  final _nationalityController    = TextEditingController();
  final _phoneController          = TextEditingController();
  final _emailController          = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController= TextEditingController();

  // ── Focus nodes (for blur-triggered validation) ────────────────────────────
  final _fullNameFocus        = FocusNode();
  final _nationalIdFocus      = FocusNode();
  final _phoneFocus           = FocusNode();
  final _emailFocus           = FocusNode();
  final _passwordFocus        = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // ── Inline error messages ──────────────────────────────────────────────────
  String? _fullNameError;
  String? _nationalIdError;
  String? _dobError;
  String? _nationalityError;
  String? _genderError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // ── State ──────────────────────────────────────────────────────────────────
  String? selectedGender;
  bool obscurePass    = true;
  bool obscureConfirm = true;
  bool _isLoading     = false;

  // ── Password strength (0–4) ────────────────────────────────────────────────
  int _passwordStrength = 0;

  final List<String> genders = ["Male", "Female"];

  final List<String> allCountries = [
    "United Arab Emirates","Saudi Arabia","Kuwait","Qatar","Bahrain","Oman",
    "Egypt","Jordan","Lebanon","Syria","Iraq","India","Pakistan","Bangladesh",
    "Philippines","United Kingdom","United States","Canada","Australia",
    "Germany","France",
  ];

  // ── Validators ─────────────────────────────────────────────────────────────
  String? _validateFullName(String v) {
    if (v.trim().isEmpty) return "Full name is required.";
    if (!v.trim().contains(" ")) return "Enter first & last name.";
    return null;
  }

  String? _validateNationalId(String v) {
    final regex = RegExp(r"^784-\d{4}-\d{7}-\d{1}$");
    if (v.trim().isEmpty) return "Emirates ID is required.";
    if (!regex.hasMatch(v.trim())) return "Format: 784-YYYY-XXXXXXX-X";
    return null;
  }

  String? _validatePhone(String v) {
    if (v.trim().isEmpty) return "Phone number is required.";
    if (!RegExp(r"^05\d{8}$").hasMatch(v.trim())) {
      return "Format: 05XXXXXXXX (UAE number)";
    }
    return null;
  }

  String? _validateEmail(String v) {
    if (v.trim().isEmpty) return "Email is required.";
    if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(v.trim())) {
      return "Enter a valid email address.";
    }
    return null;
  }

  String? _validatePassword(String v) {
    if (v.isEmpty) return "Password is required.";
    if (v.length < 8) return "At least 8 characters required.";
    if (!RegExp(r"[A-Z]").hasMatch(v)) return "Add at least one uppercase letter.";
    if (!RegExp(r"[a-z]").hasMatch(v)) return "Add at least one lowercase letter.";
    if (!RegExp(r"[0-9]").hasMatch(v)) return "Add at least one number.";
    if (!RegExp(r'[!@#\$%\^&\*\(\)\.\?\:"\{\}\|<>]').hasMatch(v)) {
      return "Add at least one special character.";
    }
    return null;
  }

  String? _validateConfirmPassword(String v) {
    if (v.isEmpty) return "Please confirm your password.";
    if (v != _passwordController.text) return "Passwords do not match.";
    return null;
  }

  // ── Password strength calculator ───────────────────────────────────────────
  int _calcStrength(String v) {
    int score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r"[A-Z]").hasMatch(v)) score++;
    if (RegExp(r"[0-9]").hasMatch(v)) score++;
    if (RegExp(r'[!@#\$%\^&\*\(\)\.\?\:"\{\}\|<>]').hasMatch(v)) score++;
    return score;
  }

  Color _strengthColor(int s) {
    if (s <= 1) return Colors.red;
    if (s == 2) return Colors.orange;
    if (s == 3) return Colors.amber;
    return Colors.green;
  }

  String _strengthLabel(int s) {
    if (s <= 1) return "Weak";
    if (s == 2) return "Fair";
    if (s == 3) return "Good";
    return "Strong";
  }

  // ── National ID auto-formatter ─────────────────────────────────────────────
  // Formats raw digits into 784-YYYY-XXXXXXX-X as user types
  String _formatEmiratesId(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 15; i++) {
      if (i == 3 || i == 7 || i == 14) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  // ── Is form fully valid? (drives button enabled state) ────────────────────
  bool get _isFormValid {
    return _validateFullName(_fullNameController.text) == null &&
        _validateNationalId(_nationalIdController.text) == null &&
        _dobController.text.isNotEmpty &&
        _nationalityController.text.isNotEmpty &&
        selectedGender != null &&
        _validatePhone(_phoneController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null;
  }

  @override
  void initState() {
    super.initState();

    // Blur listeners — validate on focus loss
    _fullNameFocus.addListener(() {
      if (!_fullNameFocus.hasFocus) {
        setState(() =>
            _fullNameError = _validateFullName(_fullNameController.text));
      }
    });
    _nationalIdFocus.addListener(() {
      if (!_nationalIdFocus.hasFocus) {
        setState(() =>
            _nationalIdError = _validateNationalId(_nationalIdController.text));
      }
    });
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus) {
        setState(() => _phoneError = _validatePhone(_phoneController.text));
      }
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        setState(() => _emailError = _validateEmail(_emailController.text));
      }
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) {
        setState(() =>
            _passwordError = _validatePassword(_passwordController.text));
      }
    });
    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        setState(() => _confirmPasswordError =
            _validateConfirmPassword(_confirmPasswordController.text));
      }
    });

    // Live password strength + confirm match
    _passwordController.addListener(() {
      setState(() {
        _passwordStrength = _calcStrength(_passwordController.text);
        _passwordError = null; // clear error while typing
        // re-validate confirm if already touched
        if (_confirmPasswordController.text.isNotEmpty) {
          _confirmPasswordError =
              _validateConfirmPassword(_confirmPasswordController.text);
        }
      });
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPasswordController.text.isNotEmpty) {
        setState(() => _confirmPasswordError =
            _validateConfirmPassword(_confirmPasswordController.text));
      }
    });
    _fullNameController.addListener(() => setState(() => _fullNameError = null));
    _nationalIdController.addListener(() => setState(() => _nationalIdError = null));
    _phoneController.addListener(() => setState(() => _phoneError = null));
    _emailController.addListener(() => setState(() => _emailError = null));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nationalIdController.dispose();
    _dobController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameFocus.dispose();
    _nationalIdFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.day}/${picked.month}/${picked.year}";
        _dobError = null;
      });
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    // Final validation sweep
    setState(() {
      _fullNameError    = _validateFullName(_fullNameController.text);
      _nationalIdError  = _validateNationalId(_nationalIdController.text);
      _dobError         = _dobController.text.isEmpty ? "Date of birth is required." : null;
      _nationalityError = _nationalityController.text.isEmpty ? "Nationality is required." : null;
      _genderError      = selectedGender == null ? "Please select your gender." : null;
      _phoneError       = _validatePhone(_phoneController.text);
      _emailError       = _validateEmail(_emailController.text);
      _passwordError    = _validatePassword(_passwordController.text);
      _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
    });

    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final hashedId    = auth.hashData(_nationalIdController.text.trim());
    final hashedPhone = auth.hashData(_phoneController.text.trim());

    final error = await auth.signUpWithDetails(
      name: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: hashedPhone,
      extraData: {
        "fullName": _fullNameController.text.trim(),
        "nationalId": hashedId,
        "role": "patient",
      },
      sensitiveData: {
        "dob": _dobController.text.trim(),
        "nationality": _nationalityController.text.trim(),
        "gender": selectedGender,
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Account created! Please verify your email.")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
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
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Image.asset("assets/images/logo.png",
                              width: 70, height: 70),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Create Your Account",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  _fieldLabel("Full Name"),
                  _inputField(
                    controller: _fullNameController,
                    focusNode: _fullNameFocus,
                    hint: "e.g. Meriem Bettayeb",
                    icon: Icons.person,
                    error: _fullNameError,
                  ),
                  const SizedBox(height: 16),

                  // Emirates ID with auto-format
                  _fieldLabel("Emirates ID"),
                  _inputField(
                    controller: _nationalIdController,
                    focusNode: _nationalIdFocus,
                    hint: "784-YYYY-XXXXXXX-X",
                    icon: Icons.badge,
                    error: _nationalIdError,
                    inputFormatters: [
                      TextInputFormatter.withFunction((old, next) {
                        final formatted = _formatEmiratesId(next.text);
                        return TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                              offset: formatted.length),
                        );
                      }),
                    ],
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  _fieldLabel("Date of Birth"),
                  _dobField(),
                  const SizedBox(height: 16),

                  // Nationality
                  _fieldLabel("Nationality"),
                  _nationalityField(),
                  const SizedBox(height: 16),

                  // Gender
                  _fieldLabel("Gender"),
                  _genderField(),
                  const SizedBox(height: 16),

                  // Phone
                  _fieldLabel("Phone Number"),
                  _inputField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    hint: "e.g. 0501234567",
                    icon: Icons.phone,
                    error: _phoneError,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _fieldLabel("Email"),
                  _inputField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hint: "e.g. example@gmail.com",
                    icon: Icons.email,
                    error: _emailError,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _fieldLabel("Password"),
                  _passwordField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hint: "Strong@Pass1",
                    obscure: obscurePass,
                    error: _passwordError,
                    toggle: () =>
                        setState(() => obscurePass = !obscurePass),
                  ),
                  // Strength bar
                  if (_passwordController.text.isNotEmpty)
                    _passwordStrengthWidget(),
                  const SizedBox(height: 16),

                  // Confirm Password
                  _fieldLabel("Confirm Password"),
                  _passwordField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    hint: "Repeat your password",
                    obscure: obscureConfirm,
                    error: _confirmPasswordError,
                    toggle: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                  const SizedBox(height: 28),

                  // Submit button — disabled until form is valid
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isFormValid)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        disabledBackgroundColor:
                            const Color(0xFF009688).withValues(alpha: 0.4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text(
                              "Create Account",
                              style: TextStyle(
                                  fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Sign In",
                          style: TextStyle(
                              color: Color(0xFF009688),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF374151)),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    String? error,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null
                ? Colors.red.shade50
                : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border: error != null
                ? Border.all(color: Colors.red.shade300)
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, color: const Color(0xFF009688)),
              hintText: hint,
              border: InputBorder.none,
            ),
          ),
        ),
        if (error != null) _errorText(error),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error != null
                ? Colors.red.shade50
                : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border: error != null
                ? Border.all(color: Colors.red.shade300)
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline,
                  color: Color(0xFF009688)),
              hintText: hint,
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: toggle,
              ),
            ),
          ),
        ),
        if (error != null) _errorText(error),
      ],
    );
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 13, color: Colors.red),
          const SizedBox(width: 4),
          Text(msg,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _passwordStrengthWidget() {
    final color = _strengthColor(_passwordStrength);
    final label = _strengthLabel(_passwordStrength);
    final reqs = [
      _Requirement("At least 8 characters",
          _passwordController.text.length >= 8),
      _Requirement("One uppercase letter (A-Z)",
          RegExp(r"[A-Z]").hasMatch(_passwordController.text)),
      _Requirement("One lowercase letter (a-z)",
          RegExp(r"[a-z]").hasMatch(_passwordController.text)),
      _Requirement("One number (0-9)",
          RegExp(r"[0-9]").hasMatch(_passwordController.text)),
      _Requirement(
          "One special character (!@#\$...)",
          RegExp(r'[!@#\$%\^&\*\(\)\.\?\:"\{\}\|<>]')
              .hasMatch(_passwordController.text)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _passwordStrength / 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // Requirements checklist
          ...reqs.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      r.met
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: r.met ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(r.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: r.met
                                ? Colors.green
                                : Colors.grey.shade600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _dobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _selectDOB,
          child: AbsorbPointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _dobError != null
                    ? Colors.red.shade50
                    : const Color(0xFFF2F5F7),
                borderRadius: BorderRadius.circular(14),
                border: _dobError != null
                    ? Border.all(color: Colors.red.shade300)
                    : null,
              ),
              child: TextField(
                controller: _dobController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today,
                      color: Color(0xFF009688)),
                  hintText: "DD/MM/YYYY",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        if (_dobError != null) _errorText(_dobError!),
      ],
    );
  }

  Widget _nationalityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            List<String> filtered = List.from(allCountries);
            final search = TextEditingController();

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setSheet) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          hintText: "Search nationality",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setSheet(() {
                          filtered = allCountries
                              .where((e) => e
                                  .toLowerCase()
                                  .contains(v.toLowerCase()))
                              .toList();
                        }),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(filtered[i]),
                            onTap: () {
                              setState(() {
                                _nationalityController.text = filtered[i];
                                _nationalityError = null;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _nationalityError != null
                  ? Colors.red.shade50
                  : const Color(0xFFF2F5F7),
              borderRadius: BorderRadius.circular(14),
              border: _nationalityError != null
                  ? Border.all(color: Colors.red.shade300)
                  : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.flag, color: Color(0xFF009688)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _nationalityController.text.isEmpty
                        ? "Select nationality"
                        : _nationalityController.text,
                    style: TextStyle(
                      color: _nationalityController.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (_nationalityError != null) _errorText(_nationalityError!),
      ],
    );
  }

  Widget _genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _genderError != null
                ? Colors.red.shade50
                : const Color(0xFFF2F5F7),
            borderRadius: BorderRadius.circular(14),
            border: _genderError != null
                ? Border.all(color: Colors.red.shade300)
                : null,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selectedGender,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline,
                  color: Color(0xFF009688)),
              border: InputBorder.none,
              hintText: "Select gender",
            ),
            items: genders
                .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() {
              selectedGender = v;
              _genderError = null;
            }),
          ),
        ),
        if (_genderError != null) _errorText(_genderError!),
      ],
    );
  }
}

class _Requirement {
  final String label;
  final bool met;
  const _Requirement(this.label, this.met);
}
