import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../data/bible_highlights.dart';
import '../data/vida_algorithm.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';
import 'biblia_screen.dart';

class GuardadosScreen extends StatefulWidget {
  const GuardadosScreen({super.key});

  @override
  State<GuardadosScreen> createState() => _GuardadosScreenState();
}

class _GuardadosScreenState extends State<GuardadosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<HighlightedVerse>? _highlights;
  List<VidaAssignment>? _vida;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    BibleHighlights.changes.addListener(_onChanged);
    VidaSavedStore.changes.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    BibleHighlights.changes.removeListener(_onChanged);
    VidaSavedStore.changes.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || _loading) return;
    _load();
  }

  Future<void> _load() async {
    final h = await BibleHighlights.loadVerses();
    final v = await VidaSavedStore.load();
    if (!mounted) return;
    setState(() {
      _highlights = h;
      _vida = v;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardados'),
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.emerald700,
          unselectedLabelColor: AppColors.emerald400,
          indicatorColor: AppColors.emerald600,
          tabs: const [
            Tab(text: 'Resaltados'),
            Tab(text: 'VIDA'),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.emerald600),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _HighlightsTab(
                  items: _highlights ?? const [],
                  onChanged: _load,
                ),
                _VidaTab(
                  items: _vida ?? const [],
                  onChanged: _load,
                ),
              ],
            ),
    );
  }
}

class _HighlightsTab extends StatelessWidget {
  const _HighlightsTab({required this.items, required this.onChanged});

  final List<HighlightedVerse> items;
  final VoidCallback onChanged;

  Future<void> _copy(BuildContext context, HighlightedVerse v) async {
    final payload = '${v.citation}\n"${v.text}"\n— RVR1909';
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado: ${v.citation}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _remove(BuildContext context, HighlightedVerse v) async {
    await BibleHighlights.removeRange(
      bookIndex: v.bookIndex,
      chapter: v.chapter,
      fromVerse: v.verse,
      toVerse: v.verseEnd,
    );
    onChanged();
  }

  void _open(BuildContext context, HighlightedVerse v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibliaScreen(
          isActive: true,
          initialBookIndex: v.bookIndex,
          initialChapter: v.chapter,
          initialVerse: v.verse,
          persistPosition: false,
        ),
      ),
    ).then((_) => onChanged());
  }

  void _actions(BuildContext context, HighlightedVerse v) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.menu_book_rounded,
                    color: AppColors.emerald700),
                title: const Text('Abrir en Biblia'),
                onTap: () {
                  Navigator.pop(ctx);
                  _open(context, v);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.copy_rounded, color: AppColors.emerald700),
                title: const Text('Copiar cita'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copy(context, v);
                },
              ),
              ListTile(
                leading: Icon(Icons.highlight_off_rounded,
                    color: AppColors.emerald700),
                title: const Text('Quitar resaltado'),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove(context, v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Empty(
        icon: Icons.bookmark_border_rounded,
        title: 'Sin versículos resaltados',
        subtitle:
            'En Biblia, toca un versículo y elige un color para resaltar.',
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ResponsiveBody(
      maxWidth: Breakpoints.reading,
      child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final v = items[i];
        return Material(
          color: BibleHighlightColors.fill(v.color, isDark: isDark),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _actions(context, v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.citation,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${v.text}"',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.emerald900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    );
  }
}

class _VidaTab extends StatelessWidget {
  const _VidaTab({required this.items, required this.onChanged});

  final List<VidaAssignment> items;
  final VoidCallback onChanged;

  Future<void> _share(VidaAssignment a) async {
    await Share.share(
      '${a.reference}\n"${a.text}"\n— Versículo VIDA · RVR1909',
      subject: 'Mi versículo VIDA',
    );
  }

  Future<void> _remove(VidaAssignment a) async {
    await VidaSavedStore.remove(a.id);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Empty(
        icon: Icons.eco_outlined,
        title: 'Sin versículos VIDA guardados',
        subtitle:
            'En la pestaña VIDA descubre tu versículo y tócalo en Guardar.',
      );
    }
    return ResponsiveBody(
      maxWidth: Breakpoints.reading,
      child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = items[i];
        return Material(
          color: AppColors.emerald100.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.share_rounded,
                            color: AppColors.emerald700),
                        title: const Text('Compartir'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _share(a);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded,
                            color: AppColors.emerald700),
                        title: const Text('Quitar de VIDA'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _remove(a);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco_rounded,
                          size: 16, color: AppColors.emerald600),
                      const SizedBox(width: 6),
                      Text(
                        a.reference,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${a.text}"',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.emerald900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.emerald300),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: AppColors.emerald600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
