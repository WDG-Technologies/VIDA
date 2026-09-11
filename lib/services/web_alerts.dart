import 'web_alerts_stub.dart'
    if (dart.library.html) 'web_alerts_web.dart' as impl;

/// Avisos del navegador (Notification API) sin Cloud Functions.
class WebAlerts {
  WebAlerts._();

  static Future<bool> requestPermission() => impl.requestPermission();

  static Future<bool> isGranted() => impl.isGranted();

  static Future<void> show({
    required String title,
    required String body,
  }) =>
      impl.show(title: title, body: body);
}
