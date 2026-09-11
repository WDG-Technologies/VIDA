import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/daily_verse.dart';
import '../data/fav.dart';
import '../data/gallery_images.dart';
import '../screens/image_editor_screen.dart';
import '../screens/oracion_guiada_screen.dart';
import '../theme/app_theme.dart';
import 'vida_verse_card.dart';

/// Pila del inicio: VIDA · Versículo del día · Oración guiada.
///
/// Mazo infinito tipo wallet: solo desliza ↑, con fundido + movimiento.
class HomeSmartStack extends StatefulWidget {
  const HomeSmartStack({
    super.key,
    required this.vidaText,
    required this.vidaReference,
    required this.vidaSaved,
    this.onShareVida,
    this.onSaveVida,
  });

  final String vidaText;
  final String vidaReference;
  final bool vidaSaved;
  final VoidCallback? onShareVida;
  final VoidCallback? onSaveVida;

  static int _dayIndex() => DailyVerseService.dayIndex();

  static String dailyGalleryAsset() {
    if (galleryAssets.isEmpty) return '';
    return galleryAssets[_dayIndex() % galleryAssets.length];
  }

  @override
  State<HomeSmartStack> createState() => _HomeSmartStackState();
}

class _HomeSmartStackState extends State<HomeSmartStack>
    with SingleTickerProviderStateMixin {
  static const _n = 3;
  static const _h = 248.0;
  /// Offset vertical grande: tras el scale aún debe asomar una franja clara.
  static const _stepY = 30.0;
  static const _stepX = 20.0;
  /// Escala suave para no “comerse” el peek.
  static const _stepScale = 0.05;
  static const _threshold = 72.0;
  static const _visible = 3;

  late final AnimationController _ctrl;
  int _index = 0;
  /// Solo avance: 0 = reposo, 1 = cambio completado.
  double _progress = 0;
  bool _busy = false;
  FavVerse? _daily;
  bool _dailyReady = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    final v = await DailyVerseService.forToday();
    if (!mounted) return;
    setState(() {
      _daily = v;
      _dailyReady = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _cardAt(int offset) => (_index + offset) % _n;

  Future<void> _shareDaily() async {
    final v = _daily;
    if (v == null) return;
    await Share.share(
      '${v.referencia}\n'
      '"${v.versiculo}"\n'
      '— Versículo del día · VIDA',
      subject: 'Versículo del día',
    );
  }

  void _createDailyImage() {
    final asset = HomeSmartStack.dailyGalleryAsset();
    final v = _daily;
    if (asset.isEmpty || v == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(
          imageAsset: asset,
          initialText: '"${v.versiculo}"\n\n— ${v.referencia}',
        ),
      ),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_busy) return;
    // Solo hacia arriba.
    if (d.delta.dy > 0 && _progress <= 0) return;
    setState(() {
      var p = _progress - d.delta.dy / _threshold;
      if (p < 0) p = 0;
      _progress = p.clamp(0.0, 1.2);
    });
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    if (_busy) return;
    final v = d.primaryVelocity ?? 0;
    final goNext = _progress > 0.4 || v < -480;
    if (goNext && _progress > 0.08) {
      await _animateProgressTo(1, thenAdvance: true);
    } else {
      await _animateProgressTo(0);
    }
  }

  Future<void> _animateProgressTo(
    double target, {
    bool thenAdvance = false,
  }) async {
    _busy = true;
    final begin = _progress;
    _ctrl.duration = Duration(
      milliseconds:
          (300 + (target - begin).abs() * 140).round().clamp(300, 460),
    );
    final anim = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    void tick() {
      if (mounted) setState(() => _progress = anim.value);
    }

    anim.addListener(tick);
    try {
      await _ctrl.forward(from: 0);
    } finally {
      anim.removeListener(tick);
    }
    if (!mounted) return;
    setState(() {
      if (thenAdvance) _index = (_index + 1) % _n;
      _progress = 0;
      _busy = false;
    });
  }

  List<Widget> _cards() {
    final daily = _daily;
    final bg = HomeSmartStack.dailyGalleryAsset();
    final verseText = !_dailyReady
        ? 'Cargando…'
        : (daily?.versiculo ?? DailyVerseService.fallback.versiculo);
    final reference = !_dailyReady
        ? ''
        : (daily?.referencia ?? DailyVerseService.fallback.referencia);
    return [
      VidaVerseCard(
        margin: EdgeInsets.zero,
        eyebrow: 'TU VERSÍCULO · VIDA',
        verseText: widget.vidaText,
        reference: widget.vidaReference,
        saved: widget.vidaSaved,
        onShare: widget.onShareVida,
        onSave: widget.onSaveVida,
      ),
      _DailyVerseCard(
        verseText: verseText,
        reference: reference,
        imageAsset: bg,
        onShare: _dailyReady ? _shareDaily : null,
        onCreateImage: _dailyReady ? _createDailyImage : null,
      ),
      _PrayerCard(onTap: () => openOracionGuiada(context)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards();
    final p = _progress.clamp(0.0, 1.0);
    const stackH = _h + (_visible - 1) * _stepY;
    final widgets = <Widget>[];

    for (var depth = _visible - 1; depth >= 0; depth--) {
      final cardI = _cardAt(depth);
      late final double visualDepth;
      var exitY = 0.0;
      var fade = 1.0;

      if (depth == 0) {
        visualDepth = 0;
        final ease = Curves.easeIn.transform(p);
        exitY = -_h * 0.42 * ease;
        // Fundido fuerte además del deslizamiento.
        fade = (1.0 - Curves.easeIn.transform(p)).clamp(0.0, 1.0);
      } else {
        visualDepth = depth - p;
        // Cartas traseras bien visibles (no fantasmas).
        fade = (0.88 + 0.12 * (1.0 - (visualDepth / _visible)))
            .clamp(0.82, 1.0);
      }

      widgets.add(
        _placed(
          depth: visualDepth,
          exitY: exitY,
          fade: fade,
          child: cards[cardI],
          interactive: depth == 0 && p == 0,
          elevated: depth == 0,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: stackH,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onVerticalDragCancel: () {
                if (!_busy) _animateProgressTo(0);
              },
              child: Stack(clipBehavior: Clip.none, children: widgets),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Desliza ↑ · se repite',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 10,
            color: AppColors.emerald600.withValues(alpha: 0.38),
          ),
        ),
      ],
    ),
      ),
    );
  }

  Widget _placed({
    required double depth,
    required Widget child,
    double exitY = 0,
    double fade = 1,
    required bool interactive,
    required bool elevated,
  }) {
    final scale = math.max(0.86, 1.0 - depth * _stepScale);
    final dy = math.max(0.0, depth) * _stepY + exitY;
    final inset = math.max(0.0, depth) * _stepX;
    final opacity = (fade).clamp(0.0, 1.0);

    return Positioned(
      top: dy,
      left: inset,
      right: inset,
      height: _h,
      child: IgnorePointer(
        ignoring: !interactive,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: depth > 0.15
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: elevated ? 0.20 : 0.14,
                    ),
                    blurRadius: elevated ? 18 : 12,
                    offset: Offset(0, elevated ? 8 : 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child:
                    SizedBox(height: _h, width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyVerseCard extends StatelessWidget {
  const _DailyVerseCard({
    required this.verseText,
    required this.reference,
    required this.imageAsset,
    this.onShare,
    this.onCreateImage,
  });

  final String verseText;
  final String reference;
  final String imageAsset;
  final VoidCallback? onShare;
  final VoidCallback? onCreateImage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAsset.isNotEmpty)
            Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              // Galería es ~1920px; la card del inicio no necesita full-res.
              cacheWidth: (MediaQuery.sizeOf(context).width.clamp(320, 960) *
                      MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(400, 1400),
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: Theme.of(context).colorScheme.primary),
            )
          else
            ColoredBox(color: Theme.of(context).colorScheme.primary),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59000000),
                  Color(0x8C000000),
                  Color(0xB8000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERSÍCULO DEL DÍA',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    '"$verseText"',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 17,
                      color: Colors.white,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '— $reference',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(
                      icon: Icons.share_rounded,
                      label: 'Compartir',
                      onTap: onShare,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.image_rounded,
                      label: 'Crear imagen',
                      onTap: onCreateImage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.onTap});

  final VoidCallback onTap;

  static const _dusk = Color(0xFF2D1B4E);
  static const _rose = Color(0xFF7C3AED);
  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_dusk, Color(0xFF4C1D95), _rose],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -30,
                child: Icon(
                  Icons.nights_stay_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                left: -10,
                top: 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _amber.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORACIÓN GUIADA',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: _amber.withValues(alpha: 0.95),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Una historia con Dios',
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pasos suaves: gratitud, arrepentimiento, alabanza, '
                      'confianza y fe. A tu ritmo.',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Toca para comenzar →',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
