import 'package:flutter/material.dart';
import '../data/bible_study.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in.dart';
import 'add_estudio_screen.dart';
import 'estudio_detalle_screen.dart';

class EstudioBiblicoScreen extends StatefulWidget {
  const EstudioBiblicoScreen({super.key});

  @override
  State<EstudioBiblicoScreen> createState() => _EstudioBiblicoScreenState();
}

class _EstudioBiblicoScreenState extends State<EstudioBiblicoScreen> {
  List<BibleStudy> _studies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final studies = await BibleStudyService.getAll();
    if (!mounted) return;
    setState(() => _studies = studies);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estudio bíblico')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEstudioScreen()),
          );
          _load();
        },
        backgroundColor: AppColors.emerald600,
        foregroundColor: Colors.white,
        child: Icon(Icons.add_rounded),
      ),
      body: _studies.isEmpty
          ? FadeIn(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 56, color: AppColors.emerald200),
                    const SizedBox(height: 16),
                    Text(
                      'Sin estudios aún',
                      style: TextStyle(fontFamily: 'DM Sans', 
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.emerald600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca + para comenzar',
                      style: TextStyle(fontFamily: 'DM Sans', 
                        fontSize: 13,
                        color: AppColors.emerald400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _studies.length,
              itemBuilder: (context, i) {
                final s = _studies[i];
                final months = [
                  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
                ];
                final day = s.date.day.toString().padLeft(2, '0');
                final month = months[s.date.month - 1];
                return FadeIn(
                  index: i,
                  child: Dismissible(
                    key: ValueKey(s.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      setState(() =>
                          _studies = _studies.where((e) => e.id != s.id).toList());
                      try {
                        await BibleStudyService.delete(s.id);
                      } catch (_) {}
                      if (mounted) await _load();
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => EstudioDetalleScreen(study: s)),
                          );
                          if (result == true) _load();
                        },
                        child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: TextStyle(fontFamily: 'DM Sans', 
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$day $month',
                                  style: TextStyle(fontFamily: 'DM Sans', 
                                    fontSize: 12,
                                    color: AppColors.emerald500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.book + (s.verses.isNotEmpty ? ' ${s.verses}' : ''),
                              style: TextStyle(fontFamily: 'DM Sans', 
                                fontSize: 13,
                                color: AppColors.emerald700,
                              ),
                            ),
                            if (s.reflection.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                s.reflection,
                                style: TextStyle(fontFamily: 'DM Sans', 
                                  fontSize: 12,
                                  color: AppColors.emerald600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                );
              },
            ),
    );
  }
}
