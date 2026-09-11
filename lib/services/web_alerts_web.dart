import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestPermission() async {
  try {
    final perm = (await web.Notification.requestPermission().toDart).toDart;
    return perm == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> isGranted() async {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> show({
  required String title,
  required String body,
}) async {
  try {
    if (web.Notification.permission != 'granted') {
      final ok = await requestPermission();
      if (!ok) return;
    }
    if (body.trim().isEmpty) return;
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: 'icons/Icon-192.png',
      ),
    );
  } catch (_) {}
}
