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
    apiKey: 'AIzaSyBp9FCyBn5gQHx87OuI3xlcR8EGrrUZFvk',
    appId: '1:56817204621:web:953ec846f2fb8303d551c4',
    messagingSenderId: '56817204621',
    projectId: 'queueless-2f4c8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBp9FCyBn5gQHx87OuI3xlcR8EGrrUZFvk',
    appId: '1:56817204621:android:5cadf43f58e18b58d551c4',
    messagingSenderId: '56817204621',
    projectId: 'queueless-2f4c8',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBp9FCyBn5gQHx87OuI3xlcR8EGrrUZFvk',
    appId: '1:56817204621:ios:bfb534867bf1aaf7d551c4',
    messagingSenderId: '56817204621',
    projectId: 'queueless-2f4c8',
    iosBundleId: 'com.example.queueless',
  );
}
