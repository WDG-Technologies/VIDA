import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Arranque/reintento de Firebase (pensado para Safari iOS).
///
/// No consulta `Firebase.apps` antes del primer `initializeApp` (en web
/// release eso puede lanzar *Null check operator used on a null value*).
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool>? _ensureFuture;
  static Future<void>? _appInit;
  static Future<void>? _authInFlight;
  static bool _firestoreConfigured = false;
  static bool _appReady = false;
  static String? lastError;

  static bool get isReady {
    if (_appReady) return true;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool _hasAppsSafe() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// [force] = true en el botón Reintentar tras un fallo.
  static Future<bool> ensure({
    bool force = false,
    Duration appTimeout = const Duration(seconds: 18),
  }) {
    if (force) {
      _ensureFuture = null;
    }

    if (_appReady || _hasAppsSafe()) {
      _appReady = true;
      _configureFirestoreWeb();
      unawaited(_ensureAuth());
      return Future<bool>.value(true);
    }

    return _ensureFuture ??= _ensureImpl(appTimeout).then((ok) {
      if (!ok) _ensureFuture = null;
      return ok;
    });
  }

  static Future<bool> _ensureImpl(Duration appTimeout) async {
    lastError = null;
    try {
      _appInit ??= _initializeAppOnly();

      try {
        await _appInit!.timeout(appTimeout);
      } on TimeoutException {
        lastError =
            'Timeout iniciando Firebase (${appTimeout.inSeconds}s). Reintenta.';
        debugPrint('[VIDA:Firebase] $lastError');
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!_hasAppsSafe() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }

      if (!_hasAppsSafe()) {
        _appInit = null;
        lastError ??= 'Firebase no arrancó en este navegador';
        return false;
      }

      _appReady = true;
      _configureFirestoreWeb();
      unawaited(_ensureAuth());
      return true;
    } catch (e, st) {
      lastError = '$e';
      debugPrint('[VIDA:Firebase] ensure FAIL: $e\n$st');
      if (!_hasAppsSafe()) {
        _appInit = null;
        return false;
      }
      _appReady = true;
      _configureFirestoreWeb();
      unawaited(_ensureAuth());
      return true;
    }
  }

  static Future<void> _initializeAppOnly() async {
    if (_hasAppsSafe()) {
      _appReady = true;
      return;
    }
    debugPrint('[VIDA:Firebase] initializeApp…');
    try {
      // Nunca chequear Firebase.apps antes de esto en web release.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _appReady = true;
      debugPrint('[VIDA:Firebase] initializeApp ok');
    } catch (e) {
      final msg = '$e'.toLowerCase();
      if (_hasAppsSafe() || msg.contains('duplicate-app')) {
        _appReady = true;
        debugPrint('[VIDA:Firebase] initializeApp duplicate → ok');
        return;
      }
      rethrow;
    }
  }

  static void _configureFirestoreWeb() {
    if (!kIsWeb || _firestoreConfigured || !_hasAppsSafe()) return;
    _firestoreConfigured = true;
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      debugPrint('[VIDA:Firebase] Firestore persistence OFF (web)');
    } catch (e) {
      debugPrint('[VIDA:Firebase] firestore settings: $e');
    }
  }

  static Future<void> _ensureAuth() {
    final existing = _authInFlight;
    if (existing != null) return existing;
    if (!_hasAppsSafe()) return Future<void>.value();

    final fut = () async {
      try {
        if (kIsWeb) {
          for (final mode in <Persistence>[
            Persistence.NONE,
            Persistence.SESSION,
          ]) {
            try {
              await FirebaseAuth.instance
                  .setPersistence(mode)
                  .timeout(const Duration(seconds: 2));
              debugPrint('[VIDA:Firebase] persistence=$mode');
              break;
            } catch (_) {}
          }
        }
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance
              .signInAnonymously()
              .timeout(const Duration(seconds: 8));
          debugPrint('[VIDA:Firebase] anon ok');
        }
      } catch (e) {
        lastError = 'auth: $e';
        debugPrint('[VIDA:Firebase] auth warn: $e');
      }
    }();

    _authInFlight = fut.whenComplete(() {
      if (identical(_authInFlight, fut)) _authInFlight = null;
    });
    return fut;
  }
}
