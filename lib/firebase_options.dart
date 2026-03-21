import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
    appId: '1:1075375116232:web:7eb7f1fb31d1a5fd4e7afd',
    messagingSenderId: '1075375116232',
    projectId: 'queueless-924f7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
    appId: '1:1075375116232:android:5cadf43f58e18b58d551c4', // Reused android ID form
    messagingSenderId: '1075375116232',
    projectId: 'queueless-924f7',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCgQyIY8kYA8rTn4adyrs0mHMYT5KvmkFM',
    appId: '1:1075375116232:ios:bfb534867bf1aaf7d551c4', // Reused iOS ID form
    messagingSenderId: '1075375116232',
    projectId: 'queueless-924f7',
    iosBundleId: 'com.example.queueless',
  );
}
