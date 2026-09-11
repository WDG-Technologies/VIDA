import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/streak.dart';
import 'services/community_push.dart';
import 'services/notification_service.dart';
import 'services/telemetry.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/biblia_screen.dart';
import 'screens/community_screen.dart';
import 'screens/favorito_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mapa_iglesias_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/vida_screen.dart';

final GlobalKey<NavigatorState> vidaNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await ThemeController.instance.load();
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    await Telemetry.init();
  } catch (_) {
    // Offline / Play Services / config — app still launches without cloud.
  }
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await NotificationService.scheduleAwayReminder();
    await CommunityPushService.init();
  } catch (_) {}
  try {
    HomeWidget.setAppGroupId('group.com.vida.project');
  } catch (_) {}
  runApp(const VidaApp());
}

class VidaApp extends StatefulWidget {
  const VidaApp({super.key});

  // ignore: library_private_types_in_public_api
  static _VidaAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_VidaAppState>()!;

  @override
  State<VidaApp> createState() => _VidaAppState();
}

class _VidaAppState extends State<VidaApp> {
  bool _ready = false;
  String _userName = '';
  Uri? _pendingWidgetUri;
  StreamSubscription<Uri?>? _widgetClickSub;
  StreamSubscription<Uri>? _appLinksSub;

  String get userName => _userName;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    NotificationService.openDeepLink = _handleDeepLink;
    _loadUser();
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    _initAppLinks();
  }

  void _onThemeChanged() {
    final c = ThemeController.instance;
    // Sync soft fills before AppearanceScreen (and others) rebuild.
    AppColors.applySeeds(styleSeed: c.styleSeed, accent: c.accentColor);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _widgetClickSub?.cancel();
    _appLinksSub?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _handleDeepLink(initial);
      _appLinksSub = links.uriLinkStream.listen(_handleDeepLink);
    } catch (_) {}
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'vida') {
      _handleWidgetUri(uri);
      return;
    }
    void go(Widget page) {
      final nav = vidaNavigatorKey.currentState;
      if (nav == null) {
        _pendingWidgetUri = uri;
        return;
      }
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
    }

    switch (uri.host) {
      case 'post':
        final postId = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : (uri.path.isNotEmpty
                ? uri.path.replaceFirst('/', '')
                : null);
        go(CommunityScreen(
          focusPostId: (postId != null && postId.isNotEmpty) ? postId : null,
        ));
        Telemetry.log('deep_link', {'host': 'post'});
        break;
      case 'comunidad':
        go(const CommunityScreen());
        Telemetry.log('deep_link', {'host': 'comunidad'});
        break;
      case 'iglesia':
        go(const MapaIglesiasScreen());
        Telemetry.log('deep_link', {'host': 'iglesia'});
        break;
      case 'favorito':
        _handleWidgetUri(uri);
        break;
      default:
        break;
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final opensFavorito =
        uri.host == 'favorito' || uri.toString().contains('favorito');
    if (!opensFavorito) return;

    if (!_ready || _userName.isEmpty) {
      _pendingWidgetUri = uri;
      return;
    }
    _openFavoritoFromWidget();
  }

  void _openFavoritoFromWidget() {
    final nav = vidaNavigatorKey.currentState;
    if (nav == null) return;
    // Evita apilar varias FavoritoScreen al tocar el widget repetidas veces.
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'favorito'),
        builder: (_) => const FavoritoScreen(),
      ),
      (route) => route.settings.name != 'favorito',
    );
  }

  Future<void> _loadUser() async {
    // Resolve the name first so the UI never waits on plugins (notifications /
    // HomeWidget can hang in tests or on restricted devices).
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? '';
    } catch (_) {}

    if (mounted) setState(() => _ready = true);

    final pending = _pendingWidgetUri;
    if (pending != null && _userName.isNotEmpty) {
      _pendingWidgetUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pending.scheme == 'vida') {
          _handleDeepLink(pending);
        } else {
          _handleWidgetUri(pending);
        }
      });
    }

    unawaited(_postLaunchTasks());
  }

  Future<void> _postLaunchTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      try {
        final daysAway = await NotificationService.daysSinceLastOpen();
        if (daysAway >= 2 && await NotificationService.shouldShowToday()) {
          await NotificationService.showMotivational();
        }
        await StreakService.checkAndUpdate();
        await NotificationService.scheduleAwayReminder();
      } catch (_) {}

      if (prefs.containsKey('contra_pecado')) {
        try {
          await HomeWidget.saveWidgetData(
              'contra_pecado', prefs.getBool('contra_pecado'));
          await HomeWidget.updateWidget(
            androidName: 'ContraPecadoWidgetProvider',
            iOSName: 'ContraPecadoWidget',
          );
        } catch (_) {}
      }

      if (prefs.containsKey('favorito')) {
        try {
          await HomeWidget.saveWidgetData(
              'favorito', prefs.getBool('favorito'));
          await HomeWidget.updateWidget(
            androidName: 'FavoritoWidgetProvider',
            iOSName: 'FavoritoWidget',
          );
        } catch (_) {}
      }

      final firstPin = prefs.getBool('first_launch_pin') ?? false;
      if (!firstPin) {
        await prefs.setBool('first_launch_pin', true);
        final supported = await HomeWidget.isRequestPinWidgetSupported();
        if (supported == true) {
          await HomeWidget.requestPinWidget(
              androidName: 'ContraPecadoWidgetProvider');
        }
      }
    } catch (_) {}
  }

  void setUserName(String name) {
    setState(() => _userName = name);
    final pending = _pendingWidgetUri;
    if (pending != null && name.isNotEmpty) {
      _pendingWidgetUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleWidgetUri(pending);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeController.instance;
    final styleSeed = themeCtrl.styleSeed;
    final accent = themeCtrl.customAccent;
    return MaterialApp(
      title: 'VIDA',
      navigatorKey: vidaNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(styleSeed: styleSeed, accent: accent),
      darkTheme: AppTheme.dark(styleSeed: styleSeed, accent: accent),
      themeMode: themeCtrl.themeMode,
      builder: (context, child) {
        AppColors.bind(
          Theme.of(context).colorScheme,
          styleSeed: styleSeed,
          accent: themeCtrl.accentColor,
        );
        return child ?? const SizedBox.shrink();
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_userName.isEmpty) {
      return const SplashScreen();
    }
    return const AppShell();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static final ValueNotifier<int?> tabRequests = ValueNotifier<int?>(null);

  /// Cambia la pestaña inferior (0 Inicio · 1 Biblia · 2 VIDA · 3 Perfil).
  /// Si Perfil se abrió como ruta encima, primero vuelve al shell.
  static void goToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_AppShellState>();
    if (state != null) {
      state.selectTab(index);
      return;
    }
    tabRequests.value = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    AppShell.tabRequests.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    AppShell.tabRequests.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final i = AppShell.tabRequests.value;
    if (i == null) return;
    AppShell.tabRequests.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) selectTab(i);
    });
  }

  void selectTab(int i) => _onTabSelected(i);

  Future<void> _onTabSelected(int i) async {
    if (mounted) setState(() => _selectedIndex = i);
    if (i == 2) {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('vida_intro_shown') ?? false;
      if (!shown) {
        await prefs.setBool('vida_intro_shown', true);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.eco_rounded,
                    color: AppColors.emerald600, size: 24),
                const SizedBox(width: 8),
                Text('VIDA',
                    style: TextStyle(fontFamily: 'Cormorant Garamond', 
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald800)),
              ],
            ),
            content: Text(
              'VIDA no es solo una app, sino un algoritmo que aprende de ti. '
              'Con cada interacción —lecturas, estudios, oraciones— detecta '
              'tu momento espiritual y te asigna un versículo '
              'personalizado, justo para lo que necesitas.',
              style: TextStyle(fontFamily: 'DM Sans', 
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.emerald700),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Entendido',
                    style: TextStyle(fontFamily: 'DM Sans', 
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald600)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      BibliaScreen(
        isActive: _selectedIndex == 1,
        onGoHome: () => setState(() => _selectedIndex = 0),
      ),
      const VidaScreen(),
      const PerfilScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.emerald200, width: 1),
          ),
        ),
        child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book_rounded),
            label: 'Biblia',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco_rounded),
            label: 'VIDA',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
        ),
    );
  }
}
