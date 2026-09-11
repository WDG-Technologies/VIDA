import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:share_plus/share_plus.dart';

import '../data/vida_algorithm.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';

bool get _useLiquidGlass =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class VidaScreen extends StatefulWidget {
  const VidaScreen({super.key});

  @override
  State<VidaScreen> createState() => _VidaScreenState();
}

class _VidaScreenState extends State<VidaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  VidaAssignment? _assignment;
  bool _loading = true;
  bool _analyzing = false;
  bool _canAssign = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cur = await VidaAlgorithm.current();
    final can = await VidaAlgorithm.canAssignThisMonth();
    final saved =
        cur == null ? false : await VidaSavedStore.isSaved(cur.id);
    if (!mounted) return;
    setState(() {
      _assignment = cur;
      _canAssign = can;
      _saved = saved;
      _loading = false;
    });
  }

  Future<void> _onCenterTap() async {
    if (_analyzing) return;

    if (_assignment != null && !_canAssign) {
      final next = await VidaAlgorithm.nextAssignableDate();
      if (!mounted) return;
      final label = next == null
          ? 'el próximo mes'
          : '${next.day}/${next.month}/${next.year}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tu versículo VIDA de este mes ya está listo. '
            'Podrás descubrir uno nuevo a partir del $label.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _analyzing = true);
    HapticFeedback.mediumImpact();
    // Give the UI a moment to show the analyzing state.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      final a = await VidaAlgorithm.assign();
      final saved = await VidaSavedStore.isSaved(a.id);
      if (!mounted) return;
      setState(() {
        _assignment = a;
        _canAssign = false;
        _saved = saved;
        _analyzing = false;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo asignar: $e')),
      );
    }
  }

  Future<void> _share() async {
    final a = _assignment;
    if (a == null) return;
    await Share.share(
      '${a.reference}\n"${a.text}"\n— Versículo VIDA · RVR1909',
      subject: 'Mi versículo VIDA',
    );
  }

  Future<void> _toggleSave() async {
    final a = _assignment;
    if (a == null) return;
    if (_saved) {
      await VidaSavedStore.remove(a.id);
      if (!mounted) return;
      setState(() => _saved = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quitado de Guardados · VIDA'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await VidaSavedStore.save(a);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado en Guardados · VIDA'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _VidaAtmosphere(isDark: isDark, time: _ctrl),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ResponsiveBody(
                    maxWidth: Breakpoints.reading,
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        Text(
                          'VIDA',
                          style: TextStyle(
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.emerald900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _assignment == null
                              ? 'Toca el centro para descubrir tu versículo'
                              : (_canAssign
                                  ? 'Puedes descubrir un versículo nuevo este mes'
                                  : 'Tu versículo de este mes'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 13,
                            color: AppColors.emerald700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Center(
                            child: _useLiquidGlass
                                ? _IosLiquidHero(
                                    isDark: isDark,
                                    analyzing: _analyzing,
                                    onTap: _onCenterTap,
                                  )
                                : _ClassicHero(
                                    isDark: isDark,
                                    analyzing: _analyzing,
                                    onTap: _onCenterTap,
                                  ),
                          ),
                        ),
                        if (_assignment != null) ...[
                          _VersePanel(
                            assignment: _assignment!,
                            isDark: isDark,
                            saved: _saved,
                            onShare: _share,
                            onSave: _toggleSave,
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Analizamos tu lectura, resaltados, estudios y más '
                              '(todo queda en tu dispositivo).',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VersePanel extends StatelessWidget {
  const _VersePanel({
    required this.assignment,
    required this.isDark,
    required this.saved,
    required this.onShare,
    required this.onSave,
  });

  final VidaAssignment assignment;
  final bool isDark;
  final bool saved;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emerald200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.reference.toUpperCase(),
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${assignment.text}"',
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white : AppColors.emerald900,
            ),
          ),
          if (assignment.insight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              assignment.insight,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 12,
                color: AppColors.emerald600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onShare,
                icon: Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir'),
              ),
              TextButton.icon(
                onPressed: onSave,
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                ),
                label: Text(saved ? 'Guardado' : 'Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VidaAtmosphere extends StatelessWidget {
  const _VidaAtmosphere({required this.isDark, required this.time});

  final bool isDark;
  final Animation<double> time;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF0B1411) : AppColors.emerald50;
    final accent = AppColors.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.55, -0.65),
              radius: 1.05,
              colors: [
                accent.withValues(alpha: isDark ? 0.38 : 0.28),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.7, 0.55),
              radius: 0.95,
              colors: [
                Color.lerp(accent, Colors.teal, 0.35)!
                    .withValues(alpha: isDark ? 0.32 : 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: time,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(time.value, accent),
          ),
        ),
      ],
    );
  }
}

class _IosLiquidHero extends StatelessWidget {
  const _IosLiquidHero({
    required this.isDark,
    required this.analyzing,
    required this.onTap,
  });

  final bool isDark;
  final bool analyzing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = LiquidGlassSettings(
      thickness: 28,
      blur: 10,
      chromaticAberration: 0.012,
      lightIntensity: 0.72,
      ambientStrength: 0.18,
      refractiveIndex: 1.28,
      saturation: 1.35,
      glassColor: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.14),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: LiquidGlassLayer(
            settings: settings,
            child: LiquidGlass(
              shape: const LiquidOval(),
              glassContainsChild: false,
              child: SizedBox(
                width: 148,
                height: 148,
                child: Center(
                  child: analyzing
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        )
                      : Icon(
                          Icons.eco_rounded,
                          size: 60,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          analyzing ? 'Analizando tu camino…' : 'Descubre tu versículo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.emerald900,
          ),
        ),
      ],
    );
  }
}

class _ClassicHero extends StatelessWidget {
  const _ClassicHero({
    required this.isDark,
    required this.analyzing,
    required this.onTap,
  });

  final bool isDark;
  final bool analyzing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: analyzing
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.eco_rounded, size: 60, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          analyzing ? 'Analizando tu camino…' : 'Descubre tu versículo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.emerald900,
          ),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double time;
  final Color accent;

  _ParticlePainter(this.time, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 24; i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + time * size.height * 0.15) %
          size.height;
      final radius = rng.nextDouble() * 3.5 + 1.5;
      final opacity = rng.nextDouble() * 0.16 + 0.05;
      paint.color = accent.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.time != time || old.accent != accent;
}
