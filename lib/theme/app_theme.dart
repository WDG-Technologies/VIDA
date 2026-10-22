import 'package:flutter/material.dart';
import 'theme_controller.dart';

/// Classic VIDA emerald — exact values from before dynamic theming.
class _ClassicEmerald {
  static const c50 = Color(0xFFECFDF5);
  static const c100 = Color(0xFFD1FAE5);
  static const c200 = Color(0xFFA7F3D0);
  static const c300 = Color(0xFF6EE7B7);
  static const c400 = Color(0xFF34D399);
  static const c500 = Color(0xFF10B981);
  static const c600 = Color(0xFF059669);
  static const c700 = Color(0xFF047857);
  static const c800 = Color(0xFF065F46);
  static const c900 = Color(0xFF064E3B);
}

/// Palette used across the app.
///
/// Soft fills follow the **visual theme** (classic emerald when Esmeralda).
/// [emerald500]/[emerald600] are the interactive **accent**.
/// [brand] is always the visual theme color (never the custom accent).
class AppColors {
  static ColorScheme _cs = ColorScheme.fromSeed(
    seedColor: _ClassicEmerald.c600,
  );
  static Color _styleSeed = _ClassicEmerald.c600;
  static Color _accent = _ClassicEmerald.c600;

  static void bind(
    ColorScheme scheme, {
    required Color styleSeed,
    required Color accent,
  }) {
    _cs = scheme;
    _styleSeed = styleSeed;
    _accent = accent;
  }

  /// Updates palette seeds immediately (before MaterialApp rebuilds).
  static void applySeeds({
    required Color styleSeed,
    required Color accent,
  }) {
    _styleSeed = styleSeed;
    _accent = accent;
  }

  /// 0 = fondo claro, 1 = fondo oscuro. Sigue la superficie interpolada
  /// de MaterialApp para que el cambio de modo no salte en el primer frame.
  static double get _darkT {
    final l = _cs.surface.computeLuminance();
    return (1.0 - ((l - 0.06) / 0.90)).clamp(0.0, 1.0);
  }

  static Color _tone(Color light, Color dark) =>
      Color.lerp(light, dark, _darkT) ?? light;

  static bool get isDark => _darkT >= 0.5;

  static bool get _isClassicEmerald =>
      // ignore: deprecated_member_use
      _styleSeed.value == _ClassicEmerald.c600.value;

  static Color get primary => _accent;
  static Color get surface => _cs.surface;
  static Color get onSurface => _cs.onSurface;

  /// Visual theme color (VIDA hero, brand marks). Ignores custom accent.
  static Color get brand => _isClassicEmerald ? _ClassicEmerald.c600 : _styleSeed;

  static Color get brandSoft =>
      _isClassicEmerald ? _ClassicEmerald.c100 : emerald100;

  static Color get emerald50 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c50
            : Color.lerp(_styleSeed, Colors.white, 0.92) ?? Colors.white,
        Color.lerp(_cs.surface, _styleSeed, 0.14) ??
            _cs.surfaceContainerHighest,
      );

  static Color get emerald100 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c100
            : Color.lerp(_styleSeed, Colors.white, 0.82) ?? Colors.white,
        Color.lerp(_cs.surface, _styleSeed, 0.22) ?? _cs.surfaceContainerHigh,
      );

  static Color get emerald200 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c200
            : Color.lerp(_styleSeed, Colors.white, 0.65) ?? _styleSeed,
        Colors.white.withValues(alpha: 0.08),
      );

  static Color get emerald300 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c300
            : Color.lerp(_styleSeed, Colors.white, 0.45) ?? _styleSeed,
        Color.lerp(_styleSeed, _cs.onSurface, 0.25) ?? _styleSeed,
      );

  static Color get emerald400 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c400
            : Color.lerp(_styleSeed, Colors.white, 0.2) ?? _styleSeed,
        Color.lerp(_styleSeed, _cs.onSurface, 0.1) ?? _styleSeed,
      );

  /// Accent (buttons, selected nav). Custom accent or exact theme seed.
  static Color get emerald500 =>
      // ignore: deprecated_member_use
      (_accent.value == _styleSeed.value && _isClassicEmerald)
          ? _ClassicEmerald.c500
          : _accent;

  static Color get emerald600 =>
      // ignore: deprecated_member_use
      (_accent.value == _styleSeed.value && _isClassicEmerald)
          ? _ClassicEmerald.c600
          : _accent;

  static Color get emerald700 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c700
            : Color.lerp(_styleSeed, const Color(0xFF111827), 0.35) ??
                _styleSeed,
        Color.lerp(_cs.onSurface, _styleSeed, 0.35) ?? _cs.onSurface,
      );

  static Color get emerald800 => _tone(
        _isClassicEmerald
            ? _ClassicEmerald.c800
            : Color.lerp(_styleSeed, const Color(0xFF111827), 0.5) ??
                _styleSeed,
        Color.lerp(_cs.onSurface, _styleSeed, 0.2) ?? _cs.onSurface,
      );

  static Color get emerald900 => _tone(
        _isClassicEmerald ? _ClassicEmerald.c900 : const Color(0xFF1C1917),
        _cs.onSurface,
      );

  static const amber400 = Color(0xFFFBBF24);
}

class AppTheme {
  static Color _onFor(Color bg) {
    return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : const Color(0xFF064E3B);
  }

  /// [styleSeed] drives backgrounds. [accent] overrides interactive primary only.
  static ThemeData build({
    required Brightness brightness,
    required Color styleSeed,
    Color? accent,
  }) {
    final isDark = brightness == Brightness.dark;
    final isEmerald =
        // ignore: deprecated_member_use
        styleSeed.value == _ClassicEmerald.c600.value;

    // Surfaces: keep light mode close to original (white), not muddy M3 green-gray.
    final base = ColorScheme.fromSeed(
      seedColor: styleSeed,
      brightness: brightness,
    );

    final primaryExact = accent ?? styleSeed;
    final onPrimary = _onFor(primaryExact);

    final scheme = base.copyWith(
      primary: primaryExact,
      onPrimary: onPrimary,
      primaryContainer: isDark
          ? Color.lerp(base.surface, primaryExact, 0.35)
          : Color.lerp(primaryExact, Colors.white, 0.85),
      onPrimaryContainer: isDark ? onPrimary : primaryExact,
      secondary: primaryExact,
      onSecondary: onPrimary,
      // Neutral light surfaces for classic feel
      surface: isDark ? base.surface : Colors.white,
      surfaceContainerLowest: isDark ? base.surfaceContainerLowest : Colors.white,
      surfaceContainerLow: isDark
          ? base.surfaceContainerLow
          : (isEmerald ? _ClassicEmerald.c50 : Color.lerp(styleSeed, Colors.white, 0.94)),
      surfaceContainer: isDark ? base.surfaceContainer : Colors.white,
      surfaceContainerHigh: isDark
          ? base.surfaceContainerHigh
          : Colors.white,
      surfaceContainerHighest: isDark
          ? base.surfaceContainerHighest
          : (isEmerald ? _ClassicEmerald.c50 : Color.lerp(styleSeed, Colors.white, 0.92)),
      onSurface: isDark
          ? base.onSurface
          : (isEmerald ? _ClassicEmerald.c900 : const Color(0xFF1C1917)),
    );

    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    final scaffold = scheme.surface;
    final cardColor = isDark ? base.surfaceContainerHigh : Colors.white;
    final sheetColor = isDark ? base.surfaceContainerHigh : Colors.white;

    final softFill = isDark
        ? Color.lerp(base.surface, styleSeed, 0.18) ??
            base.surfaceContainerHighest
        : isEmerald
            ? _ClassicEmerald.c50
            : Color.lerp(styleSeed, Colors.white, 0.92) ?? Colors.white;

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 14,
        color: onSurface.withValues(alpha: 0.85),
      ),
      bodySmall: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 12,
        color: onSurface.withValues(alpha: 0.65),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: cardColor,
      dividerColor: isEmerald && !isDark
          ? _ClassicEmerald.c100
          : base.outline.withValues(alpha: isDark ? 0.12 : 0.25),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.hardEdge,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: isEmerald ? _ClassicEmerald.c700 : primary),
        titleTextStyle: TextStyle(
          fontFamily: 'Cormorant Garamond',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: isEmerald && accent == null ? _ClassicEmerald.c600 : primary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: sheetColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sheetColor,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: onSurface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softFill,
        selectedColor: primary.withValues(alpha: isDark ? 0.35 : 0.18),
        labelStyle: TextStyle(
          fontFamily: 'DM Sans',
          color: onSurface,
        ),
        side: BorderSide(
          color: isEmerald && !isDark
              ? _ClassicEmerald.c200
              : base.outline.withValues(alpha: isDark ? 0.16 : 0.35),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? base.surfaceContainerHighest : softFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isEmerald && !isDark
                ? _ClassicEmerald.c200
                : base.outline.withValues(alpha: isDark ? 0.18 : 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurface.withValues(alpha: 0.7),
        ),
        hintStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: onSurface.withValues(alpha: 0.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: isDark ? base.inverseSurface : primary,
        contentTextStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          color: isDark ? base.onInverseSurface : onPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isEmerald && !isDark && accent == null
            ? _ClassicEmerald.c100
            : primary.withValues(alpha: isDark ? 0.28 : 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isEmerald && accent == null
                  ? _ClassicEmerald.c700
                  : primary,
            );
          }
          return IconThemeData(
            color: isEmerald && !isDark
                ? _ClassicEmerald.c400
                : onSurface.withValues(alpha: 0.45),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isEmerald && accent == null
                  ? _ClassicEmerald.c700
                  : primary,
            );
          }
          return TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isEmerald && !isDark
                ? _ClassicEmerald.c400
                : onSurface.withValues(alpha: 0.45),
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isEmerald && !isDark
            ? _ClassicEmerald.c100
            : base.outline.withValues(alpha: isDark ? 0.12 : 0.25),
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
    );
  }

  static ThemeData light({Color? styleSeed, Color? accent}) {
    final ctrl = ThemeController.instance;
    return build(
      brightness: Brightness.light,
      styleSeed: styleSeed ?? ctrl.style.defaultSeed,
      accent: accent ?? ctrl.customAccent,
    );
  }

  static ThemeData dark({Color? styleSeed, Color? accent}) {
    final ctrl = ThemeController.instance;
    return build(
      brightness: Brightness.dark,
      styleSeed: styleSeed ?? ctrl.style.defaultSeed,
      accent: accent ?? ctrl.customAccent,
    );
  }
}
