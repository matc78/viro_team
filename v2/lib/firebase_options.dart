// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Options Firebase pour ViroTeam v2 (projet viroteam-75303).
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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDC11KSpLJY-C07QNExa3AHuXHKk_DpXkQ',
    appId: '1:396501317680:web:93d4f0b325ff9c876fd5f5',
    messagingSenderId: '396501317680',
    projectId: 'viroteam-75303',
    authDomain: 'viroteam-75303.firebaseapp.com',
    storageBucket: 'viroteam-75303.firebasestorage.app',
    measurementId: 'G-RNK62HGCVT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAn6hnBTL6x-gmNGzyeTU4e7HOD8W1PX5c',
    appId: '1:396501317680:android:34abd5cd41ec5c626fd5f5',
    messagingSenderId: '396501317680',
    projectId: 'viroteam-75303',
    storageBucket: 'viroteam-75303.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDfmxXPQ36KEh18Z2iTCikSRbMMqrcbCE',
    appId: '1:396501317680:ios:469de638c9a9569a6fd5f5',
    messagingSenderId: '396501317680',
    projectId: 'viroteam-75303',
    storageBucket: 'viroteam-75303.firebasestorage.app',
    iosClientId:
        '396501317680-d94lrua9ulfad571djclnb5aajmsfi4e.apps.googleusercontent.com',
    iosBundleId: 'com.viroteam.viroTeam',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCDfmxXPQ36KEh18Z2iTCikSRbMMqrcbCE',
    appId: '1:396501317680:ios:469de638c9a9569a6fd5f5',
    messagingSenderId: '396501317680',
    projectId: 'viroteam-75303',
    storageBucket: 'viroteam-75303.firebasestorage.app',
    iosClientId:
        '396501317680-d94lrua9ulfad571djclnb5aajmsfi4e.apps.googleusercontent.com',
    iosBundleId: 'com.viroteam.viroTeam',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDC11KSpLJY-C07QNExa3AHuXHKk_DpXkQ',
    appId: '1:396501317680:web:b43ba67c475c65db6fd5f5',
    messagingSenderId: '396501317680',
    projectId: 'viroteam-75303',
    authDomain: 'viroteam-75303.firebaseapp.com',
    storageBucket: 'viroteam-75303.firebasestorage.app',
    measurementId: 'G-5SYN4BBR4V',
  );
}
