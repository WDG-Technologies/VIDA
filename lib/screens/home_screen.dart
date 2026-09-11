import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/streak.dart';
import '../data/vida_algorithm.dart';
import '../data/vida_signals.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in.dart';
import '../widgets/home_smart_stack.dart';
import '../widgets/tool_card.dart';
import '../widgets/user_avatar.dart';
import 'contra_pecado_screen.dart';
import 'estudio_biblico_screen.dart';
import 'favorito_screen.dart';
import 'gallery_screen.dart';
import 'streak_screen.dart';
import 'mini_arcade_screen.dart';
import 'perfil_screen.dart';
import 'situacion_dificil_screen.dart';
import 'evangelizate_screen.dart';
import 'mapa_iglesias_screen.dart';
import 'testimonios_screen.dart';
import 'community_screen.dart';
import 'guardados_screen.dart';
import 'oracion_guiada_screen.dart';
import '../data/oracion_guiada.dart';
import '../services/community_push.dart';
import '../utils/platform_caps.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _contraPecadoEnabled = false;
  bool _favoritoEnabled = false;
  int _streak = 0;
  int _bestStreak = 0;
  VidaAssignment? _vida;
  bool _vidaSaved = false;

  @override
  void initState() {
    super.initState();
    _loadContraPecado();
    _loadFavorito();
    _loadStreak();
    _loadVida();
    VidaAlgorithm.assignmentChanges.addListener(_loadVida);
    VidaSavedStore.changes.addListener(_loadVida);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInvitePrayer());
  }

  Future<void> _maybeInvitePrayer() async {
    await OracionGuiadaService.ensureFirstOpenTracked();
    if (!mounted) return;
    if (!await OracionGuiadaService.shouldShowInvite()) return;
    if (!mounted) return;
    final goPray = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Quieres orar un momento?'),
        content: const Text(
          'Notamos que llevas un tiempo en VIDA. '
          'La oración guiada te ayuda a empezar sin presión: '
          'paso a paso, a tu ritmo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Orar'),
          ),
        ],
      ),
    );
    // Solo marcar después de que el usuario vio el diálogo.
    await OracionGuiadaService.markInviteShown();
    if (!mounted) return;
    if (goPray == true) await openOracionGuiada(context);
  }

  @override
  void dispose() {
    VidaAlgorithm.assignmentChanges.removeListener(_loadVida);
    VidaSavedStore.changes.removeListener(_loadVida);
    super.dispose();
  }

  Future<void> _loadVida() async {
    final a = await VidaAlgorithm.current();
    final saved =
        a == null ? false : await VidaSavedStore.isSaved(a.id);
    if (!mounted) return;
    setState(() {
      _vida = a;
      _vidaSaved = saved;
    });
  }

  Future<void> _loadContraPecado() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _contraPecadoEnabled = prefs.getBool('contra_pecado') ?? false,
    );
  }

  Future<void> _loadFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _favoritoEnabled = prefs.getBool('favorito') ?? false,
    );
  }

  Future<void> _loadStreak() async {
    final count = await StreakService.getCount();
    final best = await StreakService.getBest();
    if (!mounted) return;
    setState(() {
      _streak = count;
      _bestStreak = best;
    });
  }

  String _dayGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _soonSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareVida() async {
    final a = _vida;
    if (a == null) {
      _soonSnack('Ve a la pestaña VIDA y descubre tu versículo');
      return;
    }
    await Share.share(
      '${a.reference}\n"${a.text}"\n— Versículo VIDA · RVR1909',
      subject: 'Mi versículo VIDA',
    );
  }

  Future<void> _toggleSaveVida() async {
    final a = _vida;
    if (a == null) {
      _soonSnack('Ve a la pestaña VIDA y descubre tu versículo');
      return;
    }
    if (_vidaSaved) {
      await VidaSavedStore.remove(a.id);
      if (!mounted) return;
      setState(() => _vidaSaved = false);
      _soonSnack('Quitado de Guardados · VIDA');
    } else {
      await VidaSavedStore.save(a);
      if (!mounted) return;
      setState(() => _vidaSaved = true);
      _soonSnack('Guardado en Guardados · VIDA');
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'DM Sans', 
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
          color: AppColors.emerald600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userName = VidaApp.of(context).userName;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIDA',
                        style: TextStyle(fontFamily: 'Cormorant Garamond', 
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${_dayGreeting()}, $userName',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: AppColors.emerald700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PerfilScreen()),
                    ),
                    child: UserAvatar(
                      name: userName,
                      radius: 19,
                      backgroundColor: cs.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            FadeIn(
              child: HomeSmartStack(
                vidaText: _vida?.text ??
                    'Toca VIDA para descubrir tu versículo del mes',
                vidaReference: _vida?.reference ?? 'Tu versículo VIDA',
                vidaSaved: _vidaSaved,
                onShareVida: _shareVida,
                onSaveVida: _toggleSaveVida,
              ),
            ),

            const SizedBox(height: 6),

            FadeIn(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StreakScreen()),
                    );
                    _loadStreak();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.emerald100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 30, color: AppColors.amber400),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: _streak),
                              duration: const Duration(milliseconds: 400),
                              builder: (_, v, __) => Text(
                                '$v',
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_streak días de racha',
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emerald900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tu mejor racha: $_bestStreak días',
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 12,
                                  color: AppColors.emerald600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.emerald500),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            FadeIn(
              index: 2,
              child: _sectionLabel('HERRAMIENTAS'),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
                children: [
                  if (PlatformCaps.homeWidgets)
                    FadeIn(
                      index: 3,
                      child: ToolCard(
                        icon: Icons.shield_rounded,
                        title: 'Contra pecado',
                        subtitle: 'Recuerdos y alertas',
                        isActive: _contraPecadoEnabled,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ContraPecadoScreen()),
                          );
                          _loadContraPecado();
                        },
                      ),
                    ),
                  FadeIn(
                    index: 4,
                    child: ToolCard(
                      icon: Icons.bookmark_rounded,
                      title: 'Guardados',
                      subtitle: 'Versículos resaltados',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GuardadosScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 5,
                    child: ToolCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Estudio bíblico',
                      subtitle: 'Explorar la Palabra',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EstudioBiblicoScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 6,
                    child: ToolCard(
                      icon: Icons.support_rounded,
                      title: 'Situación difícil',
                      subtitle: 'Versículos de ayuda',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SituacionDificilScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 7,
                    child: ToolCard(
                      icon: Icons.collections_rounded,
                      title: 'Crear imagen',
                      subtitle: 'Versículo sobre un fondo',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GalleryScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (PlatformCaps.homeWidgets)
                    FadeIn(
                      index: 8,
                      child: ToolCard(
                        icon: Icons.star_border_rounded,
                        title: 'Versículo en inicio',
                        subtitle: 'Widget en la pantalla',
                        isActive: _favoritoEnabled,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FavoritoScreen()),
                          );
                          _loadFavorito();
                        },
                      ),
                    ),
                  FadeIn(
                    index: 9,
                    child: ToolCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Evangelízate',
                      subtitle: 'Guía de evangelización',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EvangelizateScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 10,
                    child: ToolCard(
                      icon: Icons.map_rounded,
                      title: 'Mapa de iglesias',
                      subtitle: 'Encuentra congregaciones',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MapaIglesiasScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 11,
                    child: ToolCard(
                      icon: Icons.auto_stories_rounded,
                      title: 'Testimonios',
                      subtitle: 'Comparte tu fe',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TestimoniosScreen()),
                      ),
                    ),
                  ),
                  FadeIn(
                    index: 12,
                    child: ValueListenableBuilder<int>(
                      valueListenable: CommunityPushService.unreadCount,
                      builder: (context, unread, _) {
                        return ToolCard(
                          icon: Icons.forum_rounded,
                          title: 'Comunidad',
                          subtitle: unread > 0
                              ? '$unread aviso${unread == 1 ? '' : 's'} nuevo${unread == 1 ? '' : 's'}'
                              : 'Conecta con otros',
                          badgeCount: unread,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CommunityScreen()),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            FadeIn(
              index: 13,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    VidaSignals.trackEvent('arcade');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MiniArcadeScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.emerald300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sports_esports_rounded,
                            size: 30, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mini Arcade',
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '8 juegos disponibles',
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 12,
                                  color: AppColors.emerald600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.emerald500),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
