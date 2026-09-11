import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Push / inbox de Comunidad (likes y respuestas).
///
/// - Tokens en `users/{uid}/fcmTokens/{id}`
/// - Preferencia local + `users/{uid}.communityPushEnabled`
/// - Inbox `users/{toUid}/inbox` (aviso con la app abierta)
/// - Cola `fcm_dispatch` + Cloud Functions para FCM con la app cerrada
class CommunityPushService {
  CommunityPushService._();

  static const _kEnabled = 'community_push_enabled';
  static StreamSubscription<QuerySnapshot>? _inboxSub;
  // ignore: unused_field
  static StreamSubscription<String>? _tokenSub;
  // ignore: unused_field
  static StreamSubscription<RemoteMessage>? _fgSub;
  // ignore: unused_field
  static StreamSubscription<User?>? _authSub;
  static bool _started = false;
  static final Set<String> _seenInbox = {};

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {
    if (kIsWeb || _started || !_firebaseReady) return;
    _started = true;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      _fgSub = FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.notification?.title ??
            (msg.data['title'] as String?) ??
            'Comunidad VIDA';
        final body = msg.notification?.body ??
            (msg.data['body'] as String?) ??
            '';
        final postId = msg.data['postId'];
        NotificationService.showCommunity(
          title: title,
          body: body,
          payload: postId != null && postId.isNotEmpty
              ? 'vida://post/$postId'
              : 'vida://comunidad',
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          _openFromMessage(initial);
        });
      }

      await syncToken();
      _tokenSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncToken());
      await _listenInbox();
      _authSub = FirebaseAuth.instance.userChanges().listen((_) async {
        await syncToken();
        await _listenInbox();
      });
    } catch (_) {
      _started = false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || !_firebaseReady) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'communityPushEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (enabled) {
        await syncToken();
        await _listenInbox();
      } else {
        await _clearToken();
        await _inboxSub?.cancel();
        _inboxSub = null;
      }
    } catch (_) {}
  }

  static Future<void> syncToken() async {
    if (!_firebaseReady || !await isEnabled()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : 'other';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token.hashCode.toRadixString(16))
          .set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'communityPushEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token.hashCode.toRadixString(16))
          .delete();
    } catch (_) {}
  }

  static Future<void> _listenInbox() async {
    await _inboxSub?.cancel();
    _inboxSub = null;
    if (!_firebaseReady || !await isEnabled()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(20);

    var primed = false;
    _inboxSub = query.snapshots().listen((snap) {
      if (!primed) {
        for (final d in snap.docs) {
          _seenInbox.add(d.id);
        }
        primed = true;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (_seenInbox.contains(id)) continue;
        _seenInbox.add(id);
        final data = change.doc.data();
        if (data == null) return;
        final title = (data['title'] as String?)?.trim() ?? 'Comunidad VIDA';
        final body = (data['body'] as String?)?.trim() ?? '';
        final postId = data['postId'] as String?;
        NotificationService.showCommunity(
          title: title,
          body: body,
          payload: postId != null && postId.isNotEmpty
              ? 'vida://post/$postId'
              : 'vida://comunidad',
        );
      }
    });
  }

  /// Aviso para el autor del post (like o respuesta).
  static Future<void> notifyAuthor({
    required String toUid,
    required String type, // like | comment
    required String postId,
    required String fromName,
  }) async {
    if (!_firebaseReady) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.isAnonymous) return;
    if (toUid.isEmpty || toUid == me.uid) return;

    final name = fromName.trim().isEmpty ? 'Alguien' : fromName.trim();
    const title = 'Comunidad VIDA';
    final body = type == 'like'
        ? '$name le gustó tu publicación'
        : '$name respondió a tu publicación';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(toUid)
          .collection('inbox')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'postId': postId,
        'fromUid': me.uid,
        'fromName': name,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}

    try {
      await FirebaseFirestore.instance.collection('fcm_dispatch').add({
        'toUid': toUid,
        'title': title,
        'body': body,
        'data': {
          'type': type,
          'postId': postId,
          'host': 'comunidad',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'client',
      });
    } catch (_) {}
  }

  static void _openFromMessage(RemoteMessage msg) {
    final postId = msg.data['postId'];
    final uri = (postId != null && postId.isNotEmpty)
        ? Uri(scheme: 'vida', host: 'post', pathSegments: [postId])
        : Uri(scheme: 'vida', host: 'comunidad');
    NotificationService.openDeepLink?.call(uri);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // El sistema muestra la notificación; no hace falta UI aquí.
}
