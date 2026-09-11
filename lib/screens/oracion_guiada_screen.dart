import 'package:flutter/material.dart';

import '../data/oracion_guiada.dart';
import '../theme/transitions.dart';
import '../widgets/responsive_body.dart';

/// Oración guiada estilo “story”: a pantalla completa, paso a paso.
class OracionGuiadaScreen extends StatefulWidget {
  const OracionGuiadaScreen({super.key});

  @override
  State<OracionGuiadaScreen> createState() => _OracionGuiadaScreenState();
}

class _OracionGuiadaScreenState extends State<OracionGuiadaScreen>
    with SingleTickerProviderStateMixin {
  /// -1 intro, 0..n-1 pasos, n cierre
  int _beat = -1;
  late List<OracionPaso> _path;
  final _noteCtrl = TextEditingController();
  late final AnimationController _fade;
  bool _busy = false;

  static const _storyColors = <List<Color>>[
    [Color(0xFF1E3A5F), Color(0xFF0F766E)],
    [Color(0xFF4C1D95), Color(0xFF7C3AED)],
    [Color(0xFF9A3412), Color(0xFFD97706)],
    [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    [Color(0xFF064E3B), Color(0xFF059669)],
    [Color(0xFF1C1917), Color(0xFF44403C)],
  ];

  @override
  void initState() {
    super.initState();
    _path = List.of(oracionPasos);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _fade.dispose();
    super.dispose();
  }

  IconData _icon(IconDataName n) => switch (n) {
        IconDataName.favorite => Icons.favorite_rounded,
        IconDataName.repent => Icons.spa_rounded,
        IconDataName.praise => Icons.auto_awesome_rounded,
        IconDataName.trust => Icons.handshake_rounded,
        IconDataName.faith => Icons.church_rounded,
      };

  List<Color> _colorsForBeat() {
    if (_beat < 0) return _storyColors[0];
    if (_beat >= _path.length) return _storyColors.last;
    return _storyColors[_beat.clamp(0, _storyColors.length - 2)];
  }

  Future<void> _goTo(int beat) async {
    if (_busy || !mounted) return;
    if (beat == _beat) return;
    _busy = true;
    try {
      await _fade.reverse();
      if (!mounted) return;
      _noteCtrl.clear();
      setState(() => _beat = beat);
      await _fade.forward();
    } on TickerCanceled {
      // Pantalla cerrada a mitad de la animación.
    } finally {
      _busy = false;
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_beat < 0) {
      await _goTo(0);
      return;
    }
    if (_beat < _path.length - 1) {
      await _goTo(_beat + 1);
      return;
    }
    if (_beat == _path.length - 1) {
      await OracionGuiadaService.markCompleted();
      await _goTo(_path.length);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _prev() async {
    if (_busy) return;
    if (_beat == 0) {
      await _goTo(-1);
      return;
    }
    if (_beat > 0 && _beat < _path.length) {
      await _goTo(_beat - 1);
      return;
    }
    if (_beat >= _path.length) {
      await _goTo(_path.length - 1);
    }
  }

  int get _segmentCount => _path.length + 1;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForBeat();
    final isIntro = _beat < 0;
    final isAmen = _beat >= _path.length;
    final stepIdx = isIntro || isAmen ? null : _beat;
    final edgeW = Breakpoints.isDesktop(context) ? 56.0 : 22.0;

    return Scaffold(
      backgroundColor: colors.first,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: Row(
                  children: [
                    if (!isIntro)
                      Expanded(
                        child: Row(
                          children: List.generate(_segmentCount, (i) {
                            final filled = isAmen ||
                                (stepIdx != null && i <= stepIdx);
                            return Expanded(
                              child: Container(
                                height: 3,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: filled ? 0.95 : 0.28,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      )
                    else
                      const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: isIntro
                                ? _IntroStory(
                                    onStart: _next,
                                    onClose: () => Navigator.pop(context),
                                  )
                                : isAmen
                                    ? _AmenStory(
                                        onDone: () => Navigator.pop(context),
                                      )
                                    : _StepStory(
                                        paso: _path[stepIdx!],
                                        index: stepIdx + 1,
                                        total: _path.length,
                                        icon: _icon(_path[stepIdx].icon),
                                        controller: _noteCtrl,
                                        onNext: _next,
                                        onSkip: _next,
                                      ),
                          ),
                        ),
                      ),
                      // Solo márgenes estrechos; el TextField queda en el centro libre.
                      if (!isIntro && !isAmen) ...[
                        Positioned(
                          top: 0,
                          bottom: 168,
                          left: 0,
                          width: edgeW,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _prev,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 168,
                          right: 0,
                          width: edgeW,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _next,
                          ),
                        ),
                      ],
                    ],
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

class _IntroStory extends StatelessWidget {
  const _IntroStory({required this.onStart, required this.onClose});

  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          'ORACIÓN',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'No hay reloj aquí',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Una historia breve contigo y con Dios.\n'
          'Gratitud · Arrepentimiento · Alabanza · Confianza · Fe.\n\n'
          'Toca los bordes para avanzar o volver.\n'
          'Sin prisa: lo importante es orar.',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 15,
            height: 1.55,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A5F),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Comenzar',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        TextButton(
          onPressed: onClose,
          child: Text(
            'Salir',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
      ],
    );
  }
}

class _StepStory extends StatelessWidget {
  const _StepStory({
    required this.paso,
    required this.index,
    required this.total,
    required this.icon,
    required this.controller,
    required this.onNext,
    required this.onSkip,
  });

  final OracionPaso paso;
  final int index;
  final int total;
  final IconData icon;
  final TextEditingController controller;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$index / $total',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 18),
        Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.95)),
        const SizedBox(height: 14),
        Text(
          paso.title,
          style: const TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          paso.prompt,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: controller,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontFamily: 'DM Sans'),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: paso.hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const Spacer(),
        Text(
          'Bordes: atrás · adelante',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(index == total ? 'Amen' : 'Siguiente'),
        ),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'Saltar este paso',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          ),
        ),
      ],
    );
  }
}

class _AmenStory extends StatelessWidget {
  const _AmenStory({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Icon(Icons.favorite_rounded,
            size: 52, color: Colors.white.withValues(alpha: 0.95)),
        const SizedBox(height: 16),
        const Text(
          'Amén',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu tiempo con Dios no se mide en minutos.\n'
          'Él te oyó. Puedes volver cuando lo necesites.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

Future<void> openOracionGuiada(BuildContext context) {
  return Navigator.push(
    context,
    slideUpRoute(const OracionGuiadaScreen()),
  );
}
