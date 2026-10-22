import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Capacidades por plataforma (web vs nativo).
class PlatformCaps {
  PlatformCaps._();

  static bool get isWeb => kIsWeb;

  /// Widgets de pantalla de inicio (solo Android).
  /// iOS se compila con xcross, que omite `home_widget` (solo trae podspec de
  /// CocoaPods); sus llamadas lanzarían MissingPluginException. Ver ios/XCROSS.md.
  static bool get homeWidgets =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;

  /// Notificaciones locales / recordatorios programados (plugin nativo).
  static bool get localNotifications => !kIsWeb;

  /// Inbox Comunidad + avisos (móvil: locales; web: Notification API).
  /// No requiere Cloud Functions.
  static bool get communityInboxAlerts => true;

  /// Juegos HTML (Quiz/Riega): en móvil WebView; en web iframe.
  static bool get webViewGames => true;

  /// Actualización vía APK (móvil). En web se abre releases en el navegador.
  static bool get apkUpdates => !kIsWeb;

  /// Controles UIKit/SwiftUI reales (Liquid Glass en iOS 26+).
  static bool get nativeIosControls =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Hueco bajo el contenido para que no quede debajo de la tab bar flotante.
  static const double nativeTabClearance = 84;

  /// Galería libre / “Crear imagen” desde Inicio.
  /// Nativo: siempre. Web: solo pantallas anchas (no móvil).
  /// En web móvil se crea solo desde un versículo (Biblia / del día).
  static bool canBrowseImageGallery(double width) {
    if (!kIsWeb) return true;
    return width >= 700;
  }

  /// Layout de editor a dos columnas (solo web desktop).
  static bool imageEditorDesktopLayout(double width) =>
      kIsWeb && width >= 1000;
}
