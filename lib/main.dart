import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/patient/patient_hub_screen.dart';
import 'screens/patient/symptom_assessment_screen.dart';
import 'screens/patient/triage_path_screen.dart';
import 'screens/patient/manual_checkin_confirmation_screen.dart';
import 'screens/staff/staff_hub_screen.dart';
import 'utils/locale_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final savedLanguage = await LocaleHelper.loadLanguageCode();

  runApp(QueueLessApp(savedLanguage: savedLanguage));
}

class QueueLessApp extends StatefulWidget {
  final String savedLanguage;

  const QueueLessApp({super.key, required this.savedLanguage});

  @override
  State<QueueLessApp> createState() => _QueueLessAppState();
}

class _QueueLessAppState extends State<QueueLessApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = LocaleHelper.getLocale(widget.savedLanguage);
  }

  Future<void> changeLanguage(String languageCode) async {
    await LocaleHelper.saveLanguage(languageCode);

    setState(() {
      _locale = LocaleHelper.getLocale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        key: ValueKey(_locale.languageCode),
        debugShowCheckedModeBanner: false,

        locale: _locale,

        supportedLocales: const [Locale('en'), Locale('ar')],

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        builder: (context, child) {
          final isArabic = _locale.languageCode == 'ar';

          return Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox(),
          );
        },

        home: AuthGate(onLanguageChanged: changeLanguage),

        routes: {
          '/patient-hub': (context) =>
              PatientHubScreen(onLanguageChanged: changeLanguage),
          '/symptom-assessment': (context) => const SymptomAssessmentScreen(),
          '/triage-path': (context) => const TriagePathScreen(),
          '/manual-confirmation': (context) =>
              const ManualCheckinConfirmationScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final Future<void> Function(String) onLanguageChanged;

  const AuthGate({super.key, required this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.userRole == "staff") {
          return const StaffHubScreen();
        }

        if (auth.currentUser != null) {
          if (!auth.currentUser!.emailVerified) {
            return const Scaffold(
              body: Center(child: Text("Please verify your email.")),
            );
          }

          return PatientHubScreen(onLanguageChanged: onLanguageChanged);
        }

        return const LoginScreen();
      },
    );
  }
}
