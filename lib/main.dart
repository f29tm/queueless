
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:provider/provider.dart';

// import 'firebase_options.dart';
// import 'providers/auth_provider.dart';
// import 'screens/login_screen.dart';
// import 'screens/patient/patient_hub_screen.dart';
// import 'screens/staff/staff_hub_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   runApp(const QueueLessApp());
// }

// class QueueLessApp extends StatelessWidget {
//   const QueueLessApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => AuthProvider(),
//       child: const MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: AuthGate(),
//       ),
//     );
//   }
// }

// // ✅ AUTH GATE (NO StreamBuilder, NO <User>)
// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, auth, _) {
//         if (auth.currentUser == null) {
//           return const LoginScreen();
//         }

//         if (!auth.currentUser!.emailVerified) {
//           return const Scaffold(
//             body: Center(
//               child: Text("Please verify your email."),
//             ),
//           );
//         }

//         if (auth.userRole == "staff") {
//           return const StaffHubScreen();
//         }

//         if (auth.userRole == "patient") {
//           return const PatientHubScreen();
//         }

//         return const Scaffold(
//           body: Center(
//             child: Text("Unknown role. Contact support."),
//           ),
//         );
//       },
//     );
//   }
// }

//NEW
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/patient/patient_hub_screen.dart';
import 'screens/staff/staff_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const QueueLessApp());
}

class QueueLessApp extends StatelessWidget {
  const QueueLessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthGate(),
      ),
    );
  }
}

// ✅ AUTH GATE (NOW SUPPORTS STAFF WITHOUT FIREBASEAUTH)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ✅ STAFF LOGGED IN (no FirebaseAuth)
        if (auth.userRole == "staff") {
          return const StaffHubScreen();
        }

        // ✅ PATIENT LOGGED IN VIA FIREBASE AUTH
        if (auth.currentUser != null) {
          if (!auth.currentUser!.emailVerified) {
            return const Scaffold(
              body: Center(
                child: Text("Please verify your email."),
              ),
            );
          }
          return const PatientHubScreen();
        }

        // ✅ NOT LOGGED IN
        return const LoginScreen();
      },
    );
  }
}
