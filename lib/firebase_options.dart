// import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
// import 'package:flutter/foundation.dart'
//     show defaultTargetPlatform, kIsWeb, TargetPlatform;

// class DefaultFirebaseOptions {
//   static FirebaseOptions get currentPlatform {
//     if (kIsWeb) {
//       return web;
//     }
//     switch (defaultTargetPlatform) {
//       case TargetPlatform.android:
//         return android;
//       case TargetPlatform.iOS:
//         return ios;
//       case TargetPlatform.macOS:
//       case TargetPlatform.windows:
//       case TargetPlatform.linux:
//       case TargetPlatform.fuchsia:
//         throw UnsupportedError(
//           'DefaultFirebaseOptions are not supported for this platform.',
//         );
//     }
//   }

//   static const FirebaseOptions web = FirebaseOptions(
//     apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
//     appId: '1:1075375116232:web:7eb7f1fb31d1a5fd4e7afd',
//     messagingSenderId: '1075375116232',
//     projectId: 'queueless-924f7',
//   );

//   static const FirebaseOptions android = FirebaseOptions(
//     apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
//     appId: '1:1075375116232:android:5cadf43f58e18b58d551c4', // Reused android ID form
//     messagingSenderId: '1075375116232',
//     projectId: 'queueless-924f7',
//   );

//   static const FirebaseOptions ios = FirebaseOptions(
//     apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
//     appId: '1:1075375116232:ios:bfb534867bf1aaf7d551c4', // Reused iOS ID form
//     messagingSenderId: '1075375116232',
//     projectId: 'queueless-924f7',
//     iosBundleId: 'com.example.queueless',
//   );
// }

//NEW


import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ✅ WEB CONFIG
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAJrmInUD4Sm8Goyc9sFL5a2N_Ao562e-U',
    appId: '1:947503717463:web:5a755f5dc7e1d79272d712',
    messagingSenderId: '947503717463',
    projectId: 'queueless-8c498',
    authDomain: 'queueless-8c498.firebaseapp.com',
    storageBucket: 'queueless-8c498.appspot.com',
  );

  // ✅ ANDROID CONFIG
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdvz9yu8-HHXjorOQxqdg8vqarYpWPbvk',
    appId: '1:947503717463:android:9d9d614a625c9f3e72d712',
    messagingSenderId: '947503717463',
    projectId: 'queueless-8c498',
    storageBucket: 'queueless-8c498.appspot.com',
  );

  // ✅ iOS CONFIG
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'queueless-8c498',
    storageBucket: 'queueless-8c498.appspot.com',
    iosBundleId: 'com.yourcompany.queueless', // change if needed
  );
}