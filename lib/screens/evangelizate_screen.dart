import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/evangelizate_data.dart';
import '../data/vida_signals.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in.dart';
import '../widgets/tool_card.dart';
import 'evangelizate_detalle_screen.dart';

class EvangelizateScreen extends StatelessWidget {
  const EvangelizateScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    VidaSignals.trackEvent('evangelizate');
    return Scaffold(
      appBar: AppBar(title: const Text('Evangelízate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeIn(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emerald200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 20, color: AppColors.emerald600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Guía para compartir el evangelio',
                            style: TextStyle(fontFamily: 'DM Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Métodos y consejos basados en pastores y ministerios '
                      'verificables: Ray Comfort (Living Waters), Billy Graham, '
                      'Greg Laurie (Harvest), el Camino de Romanos y Cru.\n\n'
                      'Empieza por Métodos y Consejos; luego elige la situación '
                      '(obras, religioso, ateo, sufrimiento…) o cómo hablar con '
                      'familiares. Usa esto como ayuda; la autoridad final es la Biblia.',
                      style: TextStyle(fontFamily: 'DM Sans',
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.emerald700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.emerald200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  size: 20, color: AppColors.emerald500),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '«¿Te consideras una buena persona?»\n'
                                  '«Si murieras hoy, ¿irías al cielo?»',
                                  style: TextStyle(
                                    fontFamily: 'Cormorant Garamond',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                    color: AppColors.emerald900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Preguntas típicas del enfoque de Ray Comfort / Living Waters',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ..._buildGroupedCategories(context),
            const SizedBox(height: 28),
            FadeIn(
              index: 20,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'FUENTES',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald600,
                  ),
                ),
              ),
            ),
            FadeIn(
              index: 9,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < evangelizateSources.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.menu_book_outlined,
                              color: AppColors.emerald600, size: 22),
                          title: Text(
                            evangelizateSources[i].name,
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald900,
                            ),
                          ),
                          subtitle: Text(
                            evangelizateSources[i].detail,
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.emerald600,
                            ),
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 16, color: AppColors.emerald400),
                          onTap: () => _open(evangelizateSources[i].url),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedCategories(BuildContext context) {
    const groups = <(String, String)>[
      ('EMPIEZA AQUÍ', 'empezar'),
      ('SITUACIONES', 'situaciones'),
      ('CERCA DE TI', 'cercanos'),
    ];
    final out = <Widget>[];
    var fade = 1;
    for (final (label, key) in groups) {
      final cats =
          evangelizateCategories.where((c) => c.group == key).toList();
      if (cats.isEmpty) continue;
      out.add(
        FadeIn(
          index: fade++,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald600,
              ),
            ),
          ),
        ),
      );
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: [
              for (final cat in cats)
                FadeIn(
                  index: fade++,
                  child: ToolCard(
                    icon: cat.icon,
                    title: cat.shortTitle,
                    subtitle: cat.description,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EvangelizateDetalleScreen(category: cat),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return out;
  }
}
