import 'package:flutter/material.dart';
import '../data/vida_signals.dart';
import '../theme/app_theme.dart';
import '../theme/transitions.dart';
import '../widgets/responsive_body.dart';
import 'arcade_games.dart';
import 'quiz_screen.dart';
import 'riega_screen.dart';

class MiniArcadeScreen extends StatelessWidget {
  const MiniArcadeScreen({super.key});

  static const _allGames = [
    _GameData(
      icon: Icons.quiz_rounded,
      title: 'Quiz',
      subtitle: 'Preguntas bíblicas',
      webView: true,
    ),
    _GameData(
      icon: Icons.grass_rounded,
      title: 'Riega y crece',
      subtitle: 'Cultiva tu fe',
      webView: true,
    ),
    _GameData(
      icon: Icons.grid_view_rounded,
      title: 'Memorama',
      subtitle: 'Empareja versículos',
    ),
    _GameData(
      icon: Icons.sort_by_alpha_rounded,
      title: 'Ordena el versículo',
      subtitle: 'Palabras mezcladas',
    ),
    _GameData(
      icon: Icons.rule_rounded,
      title: 'Verdadero / Falso',
      subtitle: 'Pon a prueba lo que sabes',
    ),
    _GameData(
      icon: Icons.category_rounded,
      title: 'Trivia',
      subtitle: 'Por categorías',
    ),
    _GameData(
      icon: Icons.hiking_rounded,
      title: 'Camino del discípulo',
      subtitle: 'Elige con sabiduría',
    ),
    _GameData(
      icon: Icons.record_voice_over_rounded,
      title: '¿Quién lo dijo?',
      subtitle: 'Citas y personajes',
    ),
  ];

  List<_GameData> get _games => _allGames;

  void _open(BuildContext context, _GameData game) {
    VidaSignals.trackEvent('arcade');
    final Widget page = switch (game.title) {
      'Quiz' => const QuizScreen(),
      'Riega y crece' => const RiegaScreen(),
      'Memorama' => const MemoramaScreen(),
      'Ordena el versículo' => const OrdenaVersiculoScreen(),
      'Verdadero / Falso' => const VerdaderoFalsoScreen(),
      'Trivia' => const TriviaCategoriasScreen(),
      'Camino del discípulo' => const CaminoDiscipuloScreen(),
      _ => const QuienLoDijoScreen(),
    };
    Navigator.push(context, slideUpRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Arcade')),
      body: ResponsiveBody(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Breakpoints.arcadeColumns(w),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: Breakpoints.arcadeAspect(w),
                ),
                itemCount: games.length,
                itemBuilder: (_, i) => _GameCard(
                  data: games[i],
                  onTap: () => _open(context, games[i]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GameData {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool webView;
  const _GameData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.webView = false,
  });
}

class _GameCard extends StatelessWidget {
  final _GameData data;
  final VoidCallback onTap;
  const _GameCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.emerald200, width: 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.emerald100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: AppColors.emerald700),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 12,
                color: AppColors.emerald600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
