// Firebase options for VIDA (Android + Web).
// Web app: VIDA-web (1:120364406226:web:b482e6f025f1f334d6a40b)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkJnQFTE-W4Q0m5AAvCljLOP_mYktGTbs',
    appId: '1:120364406226:web:b482e6f025f1f334d6a40b',
    messagingSenderId: '120364406226',
    projectId: 'vida-86307',
    authDomain: 'vida-86307.firebaseapp.com',
    storageBucket: 'vida-86307.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBK7VRJnmMCIAIHv1_RJcnZG-UZUKwv3qg',
    appId: '1:120364406226:android:b82b89d5cabbd3e4d6a40b',
    messagingSenderId: '120364406226',
    projectId: 'vida-86307',
    storageBucket: 'vida-86307.appspot.com',
  );

  /// Placeholder hasta configurar iOS en Firebase Console.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBK7VRJnmMCIAIHv1_RJcnZG-UZUKwv3qg',
    appId: '1:120364406226:android:b82b89d5cabbd3e4d6a40b',
    messagingSenderId: '120364406226',
    projectId: 'vida-86307',
    storageBucket: 'vida-86307.appspot.com',
    iosBundleId: 'com.vida.project',
  );
}
