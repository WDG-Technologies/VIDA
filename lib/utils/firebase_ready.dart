import 'package:firebase_core/firebase_core.dart';

/// True cuando Firebase ya inicializó (evita crashes en web).
bool get firebaseReady => Firebase.apps.isNotEmpty;
