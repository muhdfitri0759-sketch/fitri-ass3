

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;




class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions tidak menyokong Web. Sila gunakan FlutterFire CLI untuk menjana semula.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak menyokong iOS/macOS buat masa ini. Sila gunakan FlutterFire CLI untuk menjana semula.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak menyokong Windows. Sila gunakan FlutterFire CLI untuk menjana semula.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak menyokong Linux. Sila gunakan FlutterFire CLI untuk menjana semula.',
        );
      default:
        throw UnsupportedError(
          'Platform tidak disokong',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBa02FAgtc-91aVenSmO9Cr4qLrIG2kkfQ',
    appId: '1:252278755172:android:a726056b7fc42c3379f471',
    messagingSenderId: '252278755172',
    projectId: 'smart-room-70ea4',
    databaseURL: 'https://smart-room-70ea4-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'smart-room-70ea4.firebasestorage.app',
  );


}