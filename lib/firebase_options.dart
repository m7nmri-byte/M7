import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Only web is supported currently.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCPMfu3SVc5XS8Mvmxahrq7zTG-LHn2zec',
    authDomain: 'm7nmri-299c3.firebaseapp.com',
    projectId: 'm7nmri-299c3',
    storageBucket: 'm7nmri-299c3.firebasestorage.app',
    messagingSenderId: '301032976291',
    appId: '1:301032976291:web:a665558e684661384f3416',
  );
}
