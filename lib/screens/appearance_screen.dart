import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/user_avatar.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _accentPresets = <Color>[
    Color(0xFF059669), // esmeralda
    Color(0xFF16A34A), // verde
    Color(0xFF65A30D), // lima
    Color(0xFF0D9488), // teal
    Color(0xFF0891B2), // cian
    Color(0xFF0284C7), // cielo
    Color(0xFF2563EB), // azul
    Color(0xFF1D4ED8), // azul profundo
    Color(0xFF4F46E5), // índigo
    Color(0xFF7C3AED), // violeta
    Color(0xFF9333EA), // morado
    Color(0xFFA855F7), // lila
    Color(0xFFC026D3), // fucsia
    Color(0xFFDB2777), // rosa
    Color(0xFFBE185D), // rosa oscuro
    Color(0xFFE11D48), // rosado intenso
    Color(0xFFDC2626), // rojo
    Color(0xFFEA580C), // naranja
    Color(0xFFD97706), // ámbar
    Color(0xFFCA8A04), // dorado
    Color(0xFFB45309), // caramelo
    Color(0xFFD6B88D), // beige
    Color(0xFFA8A29E), // arena
    Color(0xFF78716C), // piedra
    Color(0xFF57534E), // taupe
    Color(0xFF854D0E), // café
    Color(0xFF9F1239), // burdeos
    Color(0xFF334155), // pizarra
  ];

  Color _sectionLabelColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Color.lerp(cs.onSurface, cs.primary, 0.45) ?? cs.primary;
  }

  Color _styleCardBg(
    BuildContext context, {
    required Color seed,
    required bool selected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Color.lerp(
            cs.surfaceContainerHighest,
            seed,
            selected ? 0.32 : 0.16,
          ) ??
          cs.surfaceContainerHighest;
    }
    return Color.lerp(
          Colors.white,
          seed,
          selected ? 0.16 : 0.07,
        ) ??
        Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ThemeController.instance;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Apariencia')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'MODO',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: _sectionLabelColor(context),
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<AppBrightnessMode>(
                segments: [
                  for (final m in AppBrightnessMode.values)
                    ButtonSegment(
                      value: m,
                      icon: Icon(m.icon, size: 18),
                      label: Text(m.label),
                    ),
                ],
                selected: {ctrl.brightnessMode},
                onSelectionChanged: (s) => ctrl.setBrightnessMode(s.first),
              ),
              const SizedBox(height: 28),
              Text(
                'TEMA VISUAL',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: _sectionLabelColor(context),
                ),
              ),
              const SizedBox(height: 10),
              ...AppThemeStyle.values.map((style) {
                final selected = ctrl.style == style;
                final seed = style.defaultSeed;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _styleCardBg(
                      context,
                      seed: seed,
                      selected: selected,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        // Immediate soft-fill sync so the list updates this frame.
                        AppColors.applySeeds(
                          styleSeed: seed,
                          accent: ctrl.customAccent ?? seed,
                        );
                        ctrl.setStyle(style);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: seed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontFamily: 'DM Sans',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    style.subtitle,
                                    style: TextStyle(
                                      fontFamily: 'DM Sans',
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded, color: seed),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text(
                'COLOR DE ACENTO',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: _sectionLabelColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personaliza el color principal de botones, iconos y navegación. '
                '«Automático» usa el color del tema visual.',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AccentDot(
                    color: null,
                    label: 'Auto',
                    selected: ctrl.customAccent == null,
                    preview: ctrl.style.defaultSeed,
                    onTap: () {
                      AppColors.applySeeds(
                        styleSeed: ctrl.styleSeed,
                        accent: ctrl.styleSeed,
                      );
                      ctrl.setCustomAccent(null);
                    },
                  ),
                  for (final c in _accentPresets)
                    _AccentDot(
                      color: c,
                      // ignore: deprecated_member_use
                      selected: ctrl.customAccent?.value == c.value,
                      onTap: () {
                        AppColors.applySeeds(
                          styleSeed: ctrl.styleSeed,
                          accent: c,
                        );
                        ctrl.setCustomAccent(c);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showCustomPicker(context, ctrl),
                icon: Icon(Icons.palette_outlined),
                label: const Text('Mezclar color personalizado'),
              ),
              const SizedBox(height: 28),
              Text(
                'AVATAR',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: _sectionLabelColor(context),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: isDark
                    ? cs.surfaceContainerHighest
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: VidaApp.of(context).userName,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Formita',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ctrl.useFormita
                                  ? 'Figura única según tu nombre'
                                  : 'Ahora usas tu inicial',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: ctrl.useFormita,
                        onChanged: ctrl.setUseFormita,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCustomPicker(
    BuildContext context,
    ThemeController ctrl,
  ) async {
    var hue = HSVColor.fromColor(ctrl.accentColor).hue;
    var sat = HSVColor.fromColor(ctrl.accentColor).saturation;
    var val = HSVColor.fromColor(ctrl.accentColor).value;
    final cs = Theme.of(context).colorScheme;

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final color = HSVColor.fromAHSV(1, hue, sat, val).toColor();
            return AlertDialog(
              title: const Text('Color personalizado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Matiz',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                  Slider(
                    value: hue,
                    max: 360,
                    onChanged: (v) => setLocal(() => hue = v),
                  ),
                  Text('Saturación',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                  Slider(
                    value: sat,
                    onChanged: (v) => setLocal(() => sat = v),
                  ),
                  Text('Brillo',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                  Slider(
                    value: val,
                    min: 0.25,
                    onChanged: (v) => setLocal(() => val = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, color),
                  child: const Text('Usar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      AppColors.applySeeds(styleSeed: ctrl.styleSeed, accent: result);
      await ctrl.setCustomAccent(result);
    }
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.selected,
    required this.onTap,
    this.color,
    this.preview,
    this.label,
  });

  final Color? color;
  final Color? preview;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? preview ?? AppColors.emerald600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? (isDark ? Colors.white : cs.onSurface)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : cs.surface),
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: color == null
                ? Icon(Icons.auto_awesome, size: 18, color: Colors.white)
                : selected
                    ? Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 10,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
