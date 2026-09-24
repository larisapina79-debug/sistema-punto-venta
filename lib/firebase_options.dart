import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZwrkZu8q1Jb7FpqD6qYmuCtq6IQVhTS4',
    appId: '1:681747737425:web:c0e1be1c63d43fb6360170',
    messagingSenderId: '681747737425',
    projectId: 'punto-de-venta-7856d',
    authDomain: 'punto-de-venta-7856d.firebaseapp.com',
    storageBucket: 'punto-de-venta-7856d.firebasestorage.app',
    measurementId: 'G-7W9QXF7XMQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUFhfIGNPAA0QySele_u8NRXe6wFjHK2A',
    appId: '1:681747737425:android:90d77a355e0d7f3a360170',
    messagingSenderId: '681747737425',
    projectId: 'punto-de-venta-7856d',
    storageBucket: 'punto-de-venta-7856d.firebasestorage.app',
  );
}

