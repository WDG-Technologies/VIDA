import 'package:flutter/foundation.dart' show kIsWeb;

/// Capacidades por plataforma (web vs nativo).
class PlatformCaps {
  PlatformCaps._();

  static bool get isWeb => kIsWeb;

  /// Widgets de pantalla de inicio (Android/iOS).
  static bool get homeWidgets => !kIsWeb;

  /// Notificaciones locales / recordatorios programados (plugin nativo).
  static bool get localNotifications => !kIsWeb;

  /// Inbox Comunidad + avisos (móvil: locales; web: Notification API).
  /// No requiere Cloud Functions.
  static bool get communityInboxAlerts => true;

  /// Juegos HTML (Quiz/Riega): en móvil WebView; en web iframe.
  static bool get webViewGames => true;

  /// Actualización vía APK (móvil). En web se abre releases en el navegador.
  static bool get apkUpdates => !kIsWeb;
}
