import 'package:firebase_core/firebase_core.dart';

import 'firebase_bootstrap.dart';

/// True cuando Firebase ya inicializó (evita crashes en web).
bool get firebaseReady => FirebaseBootstrap.isReady;

/// Espera / reintenta init (usar desde pantallas cloud).
Future<bool> ensureFirebase({bool force = false}) =>
    FirebaseBootstrap.ensure(force: force);

/// Consulta segura de apps (no lanza en web release pre-init).
bool firebaseAppsReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return FirebaseBootstrap.isReady;
  }
}
