import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../main.dart';
import '../widgets/responsive_body.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _kAppearanceDone = 'onboarding_appearance_done';

  static const _accentPresets = <Color>[
    Color(0xFF059669),
    Color(0xFF0284C7),
    Color(0xFFD97706),
    Color(0xFF475569),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFF0D9488),
    Color(0xFFEA580C),
  ];

  final _controller = TextEditingController();
  int _step = 0; // 0 = appearance, 1 = name
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadStep();
  }

  Future<void> _loadStep() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kAppearanceDone) ?? false;
    if (!mounted) return;
    setState(() {
      _step = done ? 1 : 0;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markAppearanceDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppearanceDone, true);
  }

  Future<void> _skipAppearance() async {
    final ctrl = ThemeController.instance;
    AppColors.applySeeds(
      styleSeed: AppThemeStyle.esmeralda.defaultSeed,
      accent: AppThemeStyle.esmeralda.defaultSeed,
    );
    await ctrl.setBrightnessMode(AppBrightnessMode.light);
    await ctrl.setStyle(AppThemeStyle.esmeralda);
    await ctrl.setCustomAccent(null);
    await _markAppearanceDone();
    if (!mounted) return;
    setState(() => _step = 1);
  }

  Future<void> _continueAppearance() async {
    await _markAppearanceDone();
    if (!mounted) return;
    setState(() => _step = 1);
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    if (!mounted) return;

    VidaApp.of(context).setUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: _step == 0 ? _buildAppearance() : _buildName(),
          ),
        );
      },
    );
  }

  Widget _buildAppearance() {
    final ctrl = ThemeController.instance;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveBody(
      maxWidth: Breakpoints.form,
      child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            children: [
              Text(
                'VIDA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Personaliza tu experiencia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.emerald700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige modo, tema visual y color de acento. '
                'Podrás cambiarlo después en Perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'MODO',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald600,
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
                onSelectionChanged: (s) {
                  AppColors.applySeeds(
                    styleSeed: ctrl.styleSeed,
                    accent: ctrl.accentColor,
                  );
                  ctrl.setBrightnessMode(s.first);
                },
              ),
              const SizedBox(height: 22),
              Text(
                'TEMA VISUAL',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final style in AppThemeStyle.values)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: style.defaultSeed,
                        radius: 8,
                      ),
                      label: Text(style.label),
                      selected: ctrl.style == style,
                      onSelected: (_) {
                        AppColors.applySeeds(
                          styleSeed: style.defaultSeed,
                          accent: ctrl.customAccent ?? style.defaultSeed,
                        );
                        ctrl.setStyle(style);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'COLOR DE ACENTO',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AccentDot(
                    selected: ctrl.customAccent == null,
                    preview: ctrl.style.defaultSeed,
                    label: 'Auto',
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
                      // ignore: deprecated_member_use
                      selected: ctrl.customAccent?.value == c.value,
                      color: c,
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
              if (isDark) const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _continueAppearance,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _skipAppearance,
                child: Text(
                  'Saltar',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildName() {
    return ResponsiveBody(
      maxWidth: Breakpoints.form,
      child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'VIDA',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 56,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenido',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 18,
                color: AppColors.emerald700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '¿Cómo te llamas?',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Tu nombre',
                hintStyle: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 20,
                  color: AppColors.emerald600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.emerald50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveName,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Comenzar',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
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
            ),
            child: color == null
                ? const Icon(Icons.auto_awesome, size: 18, color: Colors.white)
                : selected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
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
