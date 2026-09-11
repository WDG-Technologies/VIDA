import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppBrightnessMode { system, light, dark }

enum AppThemeStyle {
  esmeralda,
  oceano,
  ambar,
  pizarra,
  rosa,
  morado,
}

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kMode = 'theme_brightness_mode';
  static const _kStyle = 'theme_style';
  static const _kAccent = 'theme_accent';
  static const _kFormita = 'avatar_use_formita';

  AppBrightnessMode brightnessMode = AppBrightnessMode.system;
  AppThemeStyle style = AppThemeStyle.esmeralda;
  Color? customAccent;
  /// Avatar «Formita» (Blobatar) en lugar de la inicial.
  bool useFormita = false;

  ThemeMode get themeMode => switch (brightnessMode) {
        AppBrightnessMode.system => ThemeMode.system,
        AppBrightnessMode.light => ThemeMode.light,
        AppBrightnessMode.dark => ThemeMode.dark,
      };

  /// Seed of the visual theme (backgrounds / soft fills).
  Color get styleSeed => style.defaultSeed;

  /// Interactive accent; falls back to the visual theme seed when unset.
  Color get accentColor => customAccent ?? style.defaultSeed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt(_kMode) ?? 0;
    final styleIdx = prefs.getInt(_kStyle) ?? 0;
    final accentVal = prefs.getInt(_kAccent);

    brightnessMode = AppBrightnessMode.values[
        modeIdx.clamp(0, AppBrightnessMode.values.length - 1)];
    style = AppThemeStyle
        .values[styleIdx.clamp(0, AppThemeStyle.values.length - 1)];
    customAccent = accentVal != null ? Color(accentVal) : null;
    useFormita = prefs.getBool(_kFormita) ?? false;
    notifyListeners();
  }

  Future<void> setBrightnessMode(AppBrightnessMode mode) async {
    brightnessMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMode, mode.index);
    notifyListeners();
  }

  Future<void> setStyle(AppThemeStyle value) async {
    style = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStyle, value.index);
    notifyListeners();
  }

  Future<void> setCustomAccent(Color? color) async {
    customAccent = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_kAccent);
    } else {
      // ignore: deprecated_member_use
      await prefs.setInt(_kAccent, color.value);
    }
    notifyListeners();
  }

  Future<void> setUseFormita(bool value) async {
    useFormita = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFormita, value);
    notifyListeners();
  }
}

extension AppThemeStyleX on AppThemeStyle {
  String get label => switch (this) {
        AppThemeStyle.esmeralda => 'Esmeralda',
        AppThemeStyle.oceano => 'Océano',
        AppThemeStyle.ambar => 'Ámbar',
        AppThemeStyle.pizarra => 'Pizarra',
        AppThemeStyle.rosa => 'Rosa',
        AppThemeStyle.morado => 'Morado',
      };

  String get subtitle => switch (this) {
        AppThemeStyle.esmeralda => 'Verde clásico VIDA',
        AppThemeStyle.oceano => 'Azules serenos',
        AppThemeStyle.ambar => 'Cálido y dorado',
        AppThemeStyle.pizarra => 'Grises con acento',
        AppThemeStyle.rosa => 'Rosado suave',
        AppThemeStyle.morado => 'Violeta elegante',
      };

  Color get defaultSeed => switch (this) {
        // Exact brand tones (not Material tonal muted variants).
        AppThemeStyle.esmeralda => const Color(0xFF059669),
        AppThemeStyle.oceano => const Color(0xFF0284C7),
        AppThemeStyle.ambar => const Color(0xFFD97706),
        AppThemeStyle.pizarra => const Color(0xFF475569),
        AppThemeStyle.rosa => const Color(0xFFDB2777),
        AppThemeStyle.morado => const Color(0xFF7C3AED),
      };
}

extension AppBrightnessModeX on AppBrightnessMode {
  String get label => switch (this) {
        AppBrightnessMode.system => 'Sistema',
        AppBrightnessMode.light => 'Claro',
        AppBrightnessMode.dark => 'Oscuro',
      };

  IconData get icon => switch (this) {
        AppBrightnessMode.system => Icons.brightness_auto_rounded,
        AppBrightnessMode.light => Icons.light_mode_rounded,
        AppBrightnessMode.dark => Icons.dark_mode_rounded,
      };
}
