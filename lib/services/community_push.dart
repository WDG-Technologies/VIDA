import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Avisos de Comunidad **sin Cloud Functions** (gratis).
///
/// - Escribe en `users/{toUid}/inbox`
/// - Con la app abierta: notificación local al llegar un aviso
/// - Al abrir la app: resumen de no leídos
/// - Contador [unreadCount] para badges en la UI
class CommunityPushService {
  CommunityPushService._();

  static const _kEnabled = 'community_push_enabled';
  static const _kLastSummaryCount = 'community_unread_summary_n';
  static StreamSubscription<QuerySnapshot>? _inboxSub;
  static StreamSubscription<User?>? _authSub;
  static bool _started = false;
  static final Set<String> _seenInbox = {};

  /// No leídos (para badge).
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {
    if (_started || !_firebaseReady) return;
    _started = true;

    try {
      await _refreshUnread();
      await _notifyUnreadSummary();
      await _listenInbox();
      await _authSub?.cancel();
      _authSub = FirebaseAuth.instance.userChanges().listen((_) async {
        _seenInbox.clear();
        await _refreshUnread();
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
    if (uid != null && uid.isNotEmpty && _firebaseReady) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'communityAlertsEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    if (enabled) {
      await NotificationService.requestPermission();
      await _refreshUnread();
      await _listenInbox();
    } else {
      await _inboxSub?.cancel();
      _inboxSub = null;
      unreadCount.value = 0;
      await prefs.setInt(_kLastSummaryCount, 0);
    }
  }

  static CollectionReference<Map<String, dynamic>>? _inboxRef() {
    if (!_firebaseReady) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inbox');
  }

  static Future<void> _refreshUnread() async {
    final ref = _inboxRef();
    if (ref == null || !await isEnabled()) {
      unreadCount.value = 0;
      return;
    }
    try {
      final snap = await ref.where('read', isEqualTo: false).limit(50).get();
      unreadCount.value = snap.docs.length;
    } catch (_) {
      // Sin índice o offline: no tumbar la app.
      try {
        final snap = await ref.orderBy('createdAt', descending: true).limit(30).get();
        unreadCount.value =
            snap.docs.where((d) => d.data()['read'] != true).length;
      } catch (_) {
        unreadCount.value = 0;
      }
    }
  }

  /// Al arrancar: una notificación resumen si hay pendientes nuevos.
  static Future<void> _notifyUnreadSummary() async {
    if (!await isEnabled()) return;
    final n = unreadCount.value;
    if (n <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastSummaryCount) ?? 0;
    if (n <= last) return;
    await prefs.setInt(_kLastSummaryCount, n);
    await NotificationService.showCommunity(
      title: 'Comunidad VIDA',
      body: n == 1
          ? 'Tienes 1 aviso nuevo'
          : 'Tienes $n avisos nuevos',
      payload: 'vida://comunidad',
    );
  }

  static Future<void> _listenInbox() async {
    await _inboxSub?.cancel();
    _inboxSub = null;
    if (!_firebaseReady || !await isEnabled()) return;
    final ref = _inboxRef();
    if (ref == null) return;

    final query = ref.orderBy('createdAt', descending: true).limit(30);
    var primed = false;
    _inboxSub = query.snapshots().listen((snap) {
      if (!primed) {
        for (final d in snap.docs) {
          _seenInbox.add(d.id);
        }
        primed = true;
        _refreshUnread();
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (_seenInbox.contains(id)) continue;
        _seenInbox.add(id);
        final data = change.doc.data();
        if (data == null) continue;
        if (data['read'] == true) continue;
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
      _refreshUnread();
    }, onError: (_) {});
  }

  /// Marca todo el inbox como leído (al abrir Comunidad).
  static Future<void> markAllRead() async {
    final ref = _inboxRef();
    if (ref == null) {
      unreadCount.value = 0;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSummaryCount, 0);

      for (var round = 0; round < 5; round++) {
        QuerySnapshot<Map<String, dynamic>> snap;
        try {
          snap = await ref.where('read', isEqualTo: false).limit(40).get();
        } catch (_) {
          final all =
              await ref.orderBy('createdAt', descending: true).limit(40).get();
          final unread =
              all.docs.where((d) => d.data()['read'] != true).toList();
          if (unread.isEmpty) break;
          final batch = FirebaseFirestore.instance.batch();
          for (final d in unread) {
            batch.update(d.reference, {'read': true});
          }
          await batch.commit();
          if (unread.length < 40) break;
          continue;
        }
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.update(d.reference, {'read': true});
        }
        await batch.commit();
        if (snap.docs.length < 40) break;
      }
      unreadCount.value = 0;
    } catch (_) {}
  }

  /// Aviso para el autor del post (like o respuesta) → solo inbox.
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

    // Respeta si el destinatario desactivó avisos (best-effort).
    try {
      final dest = await FirebaseFirestore.instance.collection('users').doc(toUid).get();
      if (dest.exists && dest.data()?['communityAlertsEnabled'] == false) {
        return;
      }
    } catch (_) {}

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
  }
}
