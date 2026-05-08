// ════════════════════════════════════════════════════════════════════════════
// FIREBASE OPTIONS — REPLACE ALL PLACEHOLDER VALUES BEFORE BUILDING
//
// HOW TO GET YOUR VALUES:
//   1. Go to https://console.firebase.google.com
//   2. Create a project (or open existing one)
//   3. Add an Android app with package: com.bhaichara.bhaichara
//   4. Download  google-services.json  → place it at  android/app/google-services.json
//   5. Copy the values from google-services.json into this file:
//      - apiKey           → api_key[0].current_key
//      - appId            → mobilesdk_app_id
//      - messagingSenderId → project_number
//      - projectId        → project_id
//      - storageBucket    → storage_bucket
//      - databaseURL      → Firebase Console → Realtime Database → Data tab → URL at top
//
//   ALTERNATIVELY run:  flutterfire configure
//   which auto-generates this file with your real values.
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported for Bhaichara. APK only.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // ── REPLACE EVERY VALUE BELOW ────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YAIzaSyAxDd3RbUUg5QWHz-lDdZ3G8yjSA_NOE3A',
    appId: '1:760071236471:android:f4936524d80278ffb60f72',
    messagingSenderId: '760071236471',
    projectId: 'bhaichara-15e83',
    databaseURL: 'https://bhaichara-15e83-default-rtdb.firebaseio.com',
    storageBucket: 'bhaichara-15e83.firebasestorage.app',
  );
}
