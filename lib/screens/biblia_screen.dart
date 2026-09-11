import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/bible_data.dart';
import '../data/bible_highlights.dart';
import '../data/vida_signals.dart';
import '../theme/app_theme.dart';
import '../widgets/verse_picker_sheet.dart';
import 'verse_image_screen.dart';

class BibliaScreen extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onGoHome;
  final int? initialBookIndex;
  final int? initialChapter;
  final int? initialVerse;
  /// When false (e.g. opened from Guardados), don't overwrite last reading prefs.
  final bool persistPosition;

  const BibliaScreen({
    super.key,
    required this.isActive,
    this.onGoHome,
    this.initialBookIndex,
    this.initialChapter,
    this.initialVerse,
    this.persistPosition = true,
  });

  @override
  State<BibliaScreen> createState() => _BibliaScreenState();
}

class _BibliaScreenState extends State<BibliaScreen> {
  BibleVersion? _bible;
  String? _error;
  int _bookIndex = 42; // Juan
  int _chapter = 1;
  double _fontSize = 18;
  /// verseKey → color value
  final Map<String, int> _highlights = {};
  final _scrollCtrl = ScrollController();
  final GlobalKey _focusVerseKey = GlobalKey();
  int? _scrollToVerse;

  static const _kBook = 'bible_book_index';
  static const _kChapter = 'bible_chapter';
  static const _kFont = 'bible_font_size';

  @override
  void initState() {
    super.initState();
    BibleHighlights.changes.addListener(_onHighlightsChanged);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant BibliaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _reloadHighlights();
    }
  }

  @override
  void dispose() {
    BibleHighlights.changes.removeListener(_onHighlightsChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onHighlightsChanged() {
    if (!mounted) return;
    _reloadHighlights();
  }

  Future<void> _reloadHighlights() async {
    final highlightMap = await BibleHighlights.loadMap();
    if (!mounted) return;
    setState(() {
      _highlights
        ..clear()
        ..addAll(highlightMap);
    });
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bible = await BibleService.instance.load();
      if (!mounted) return;
      final savedBook = (prefs.getInt(_kBook) ?? 42).clamp(0, bible.books.length - 1);
      final bookIndex = (widget.initialBookIndex ?? savedBook)
          .clamp(0, bible.books.length - 1);
      final maxCh = bible.books[bookIndex].chapterCount;
      final savedChapter = (prefs.getInt(_kChapter) ?? 1).clamp(1, maxCh);
      final chapter = (widget.initialChapter ?? savedChapter).clamp(1, maxCh);
      final highlightMap = await BibleHighlights.loadMap();
      if (!mounted) return;
      final verses = bible.books[bookIndex].chapter(chapter);
      final focusVerse = widget.initialVerse == null
          ? null
          : widget.initialVerse!.clamp(1, verses.isEmpty ? 1 : verses.length);
      setState(() {
        _bible = bible;
        _bookIndex = bookIndex;
        _chapter = chapter;
        _fontSize = prefs.getDouble(_kFont) ?? 18;
        _highlights
          ..clear()
          ..addAll(highlightMap);
        _scrollToVerse = focusVerse;
      });
      if (focusVerse != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureFocusVerseVisible(retries: 8);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la Biblia');
    }
  }

  void _ensureFocusVerseVisible({int retries = 0}) {
    if (!mounted) return;
    final ctx = _focusVerseKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (retries > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureFocusVerseVisible(retries: retries - 1);
      });
    }
  }

  Future<void> _persist() async {
    if (!widget.persistPosition) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBook, _bookIndex);
    await prefs.setInt(_kChapter, _chapter);
    await prefs.setDouble(_kFont, _fontSize);
  }

  String _verseKey(int verseNum) =>
      BibleHighlights.verseKey(_bookIndex, _chapter, verseNum);

  bool _isHighlighted(int verseNum) =>
      _highlights.containsKey(_verseKey(verseNum));

  Color? _highlightOf(int verseNum) {
    final v = _highlights[_verseKey(verseNum)];
    if (v == null) return null;
    return BibleHighlightColors.resolve(v);
  }

  Future<void> _applyHighlightRange({
    required int fromVerse,
    required int toVerse,
    required Color color,
  }) async {
    final a = fromVerse < toVerse ? fromVerse : toVerse;
    final b = fromVerse < toVerse ? toVerse : fromVerse;
    // ignore: deprecated_member_use
    final colorVal = color.value;
    setState(() {
      for (var v = a; v <= b; v++) {
        _highlights[_verseKey(v)] = colorVal;
      }
    });
    await BibleHighlights.applyRange(
      bookIndex: _bookIndex,
      chapter: _chapter,
      fromVerse: fromVerse,
      toVerse: toVerse,
      color: color,
    );
  }

  Future<void> _removeHighlightRange({
    required int fromVerse,
    required int toVerse,
  }) async {
    final a = fromVerse < toVerse ? fromVerse : toVerse;
    final b = fromVerse < toVerse ? toVerse : fromVerse;
    setState(() {
      for (var v = a; v <= b; v++) {
        _highlights.remove(_verseKey(v));
      }
    });
    await BibleHighlights.removeRange(
      bookIndex: _bookIndex,
      chapter: _chapter,
      fromVerse: fromVerse,
      toVerse: toVerse,
    );
  }

  /// Full contiguous highlight block for [verseNum] (same color).
  (int from, int to) _rangeContaining(int verseNum) {
    final count = _book.chapter(_chapter).length;
    return BibleHighlights.contiguousRange(
      map: _highlights,
      bookIndex: _bookIndex,
      chapter: _chapter,
      verse: verseNum,
      verseCount: count,
    );
  }

  Future<void> _removeHighlightBlock(int verseNum) async {
    final (from, to) = _rangeContaining(verseNum);
    await _removeHighlightRange(fromVerse: from, toVerse: to);
  }

  BibleBook get _book => _bible!.books[_bookIndex];

  void _goTo(int bookIndex, int chapter) {
    setState(() {
      _bookIndex = bookIndex;
      _chapter = chapter;
      _scrollToVerse = null;
    });
    _persist();
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
    // Feed VIDA algorithm (local, no account).
    try {
      final name = _bible!.books[bookIndex].name;
      VidaSignals.trackBibleBook(name);
      VidaSignals.trackChapter(bookIndex, chapter);
    } catch (_) {}
  }

  Future<void> _copyVerse(int verseNum, String text) async {
    final citation = '${_book.name} $_chapter:$verseNum';
    final payload = '$citation\n"$text"\n— ${_bible!.shortName}';
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado: $citation'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showVerseActions(int verseNum, String text) {
    final verseCount = _book.chapter(_chapter).length;
    final citation = '${_book.name} $_chapter:$verseNum';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existing = _rangeContaining(verseNum);
    var endVerse = _isHighlighted(verseNum) ? existing.$2 : verseNum;
    var selectedColor = _highlightOf(verseNum) ?? BibleHighlightColors.yellow;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final block = _rangeContaining(verseNum);
            final rangeLabel = endVerse == verseNum
                ? citation
                : '${_book.name} $_chapter:$verseNum–$endVerse';
            final anyHighlighted = _isHighlighted(verseNum);

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.emerald200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rangeLabel,
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: AppColors.emerald700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Resaltar',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.emerald800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final c in BibleHighlightColors.all) ...[
                          GestureDetector(
                            onTap: () {
                              setSheet(() => selectedColor = c);
                              _applyHighlightRange(
                                fromVerse: verseNum,
                                toVerse: endVerse,
                                color: c,
                              );
                              setSheet(() {});
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: BibleHighlightColors.fill(c, isDark: isDark),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  // ignore: deprecated_member_use
                                  color: selectedColor.value == c.value
                                      ? AppColors.emerald700
                                      : AppColors.emerald200,
                                  // ignore: deprecated_member_use
                                  width: selectedColor.value == c.value
                                      ? 2.5
                                      : 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (verseCount > 1) ...[
                      const SizedBox(height: 10),
                      Material(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final n = await showVerseNumberSheet(
                              ctx,
                              title: 'Hasta el versículo',
                              count: verseCount,
                              current: endVerse,
                            );
                            if (n == null) return;
                            final wasHighlighted = _isHighlighted(verseNum);
                            setSheet(() => endVerse = n);
                            if (wasHighlighted) {
                              _applyHighlightRange(
                                fromVerse: verseNum,
                                toVerse: n,
                                color: selectedColor,
                              );
                              setSheet(() {});
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Hasta el versículo',
                                    style: TextStyle(
                                      fontFamily: 'DM Sans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$endVerse',
                                  style: TextStyle(
                                    fontFamily: 'DM Sans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emerald700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.expand_more_rounded,
                                    color: AppColors.emerald600),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (anyHighlighted)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.emerald100,
                          child: Icon(Icons.highlight_off_rounded,
                              color: AppColors.emerald700, size: 20),
                        ),
                        title: Text(
                          block.$1 == block.$2
                              ? 'Quitar resaltado'
                              : 'Quitar resaltado ($_chapter:${block.$1}–${block.$2})',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald900,
                          ),
                        ),
                        subtitle: block.$1 == block.$2
                            ? null
                            : Text(
                                'Quita todo el rango resaltado',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 12,
                                  color: AppColors.emerald600,
                                ),
                              ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _removeHighlightBlock(verseNum);
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.emerald100,
                        child: Icon(Icons.copy_rounded,
                            color: AppColors.emerald700, size: 20),
                      ),
                      title: Text(
                        'Copiar cita',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald900,
                        ),
                      ),
                      subtitle: Text(
                        'Copia la referencia y el versículo',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: AppColors.emerald600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _copyVerse(verseNum, text);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.emerald100,
                        child: Icon(Icons.image_rounded,
                            color: AppColors.emerald700, size: 20),
                      ),
                      title: Text(
                        'Crear imagen',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald900,
                        ),
                      ),
                      subtitle: Text(
                        'Plantilla o foto con este versículo',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: AppColors.emerald600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VerseImageScreen(
                              initialBookIndex: _bookIndex,
                              initialChapter: _chapter,
                              initialVerse: verseNum,
                              initialVerseEnd: endVerse == verseNum
                                  ? null
                                  : endVerse,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _prevChapter() {
    if (_chapter > 1) {
      _goTo(_bookIndex, _chapter - 1);
    } else if (_bookIndex > 0) {
      final prev = _bible!.books[_bookIndex - 1];
      _goTo(_bookIndex - 1, prev.chapterCount);
    }
  }

  void _nextChapter() {
    if (_chapter < _book.chapterCount) {
      _goTo(_bookIndex, _chapter + 1);
    } else if (_bookIndex < _bible!.books.length - 1) {
      _goTo(_bookIndex + 1, 1);
    }
  }

  Future<void> _openYouVersion({
    required String versionId,
    int? bookIndex,
    int? chapter,
  }) async {
    final bi = bookIndex ?? _bookIndex;
    final ch = chapter ?? _chapter;
    final code = youVersionBookCodes[bi.clamp(0, youVersionBookCodes.length - 1)];
    final ref = '$code.$ch';

    final candidates = <Uri>[
      Uri.parse('youversion://bible?reference=$ref'),
      Uri.parse('https://bible.com/bible/$versionId/$ref'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        }
      } catch (_) {}
    }

    // App store / Play Store fallback
    final store = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/app/bible/id282935706')
        : Uri.parse(
            'https://play.google.com/store/apps/details?id=com.sirma.mobile.bible.android',
          );
    await launchUrl(store, mode: LaunchMode.externalApplication);
  }

  void _showReaderOptions() {
    showModalBottomSheet(
      context: context,
            shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: StatefulBuilder(
              builder: (ctx, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.emerald200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tamaño del texto',
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: _fontSize <= 14
                              ? null
                              : () {
                                  setState(() => _fontSize -= 1);
                                  setSheet(() {});
                                  _persist();
                                },
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.emerald100,
                            foregroundColor: AppColors.emerald800,
                            disabledBackgroundColor: AppColors.emerald50,
                          ),
                          icon: Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${_fontSize.round()}',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald800,
                                ),
                              ),
                              Text(
                                'Aa',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: _fontSize - 1,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emerald900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _fontSize >= 28
                              ? null
                              : () {
                                  setState(() => _fontSize += 1);
                                  setSheet(() {});
                                  _persist();
                                },
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.emerald600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.emerald200,
                          ),
                          icon: Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openYouVersion(versionId: '1718');
                        },
                        icon: Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Abrir en YouVersion'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emerald700,
                          side: BorderSide(color: AppColors.emerald300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showVersionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
            shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.emerald200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Versión de la Biblia',
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RVR1909 está incluida en la app. Otras versiones se abren en YouVersion.',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    color: AppColors.emerald600,
                  ),
                ),
                const SizedBox(height: 16),
                _VersionTile(
                  title: _bible?.name ?? 'Reina-Valera 1909',
                  subtitle: 'Incluida · Dominio público · Sin conexión',
                  selected: true,
                  badge: 'Local',
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
                Text(
                  'Más versiones',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.42,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: externalBibleVersions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final v = externalBibleVersions[i];
                      return _VersionTile(
                        title: v.name,
                        subtitle: 'Abrir en YouVersion · ${v.shortName}',
                        selected: false,
                        badge: 'YouVersion',
                        onTap: () {
                          Navigator.pop(ctx);
                          _openYouVersion(versionId: v.youVersionId);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBookPicker() {
    final bible = _bible!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
            shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.emerald200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Libros',
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_book.name} $_chapter',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _TestamentHeader('Antiguo Testamento'),
                      ...List.generate(39, (i) {
                        final b = bible.books[i];
                        return _BookRow(
                          book: b,
                          selected: i == _bookIndex,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showChapterPicker(i);
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      _TestamentHeader('Nuevo Testamento'),
                      ...List.generate(27, (i) {
                        final idx = 39 + i;
                        final b = bible.books[idx];
                        return _BookRow(
                          book: b,
                          selected: idx == _bookIndex,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showChapterPicker(idx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChapterPicker(int bookIndex) {
    final book = _bible!.books[bookIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
            shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxH = media.size.height * 0.75;
        // ~square cells in a 6-column grid + gaps
        final gridWidth = media.size.width - 40;
        final cell = (gridWidth - 5 * 8) / 6;
        final rows = (book.chapterCount / 6).ceil().clamp(1, 100);
        final gridH = rows * cell + (rows - 1) * 8;
        const headerH = 118.0;
        final sheetH = (headerH + gridH + 16).clamp(220.0, maxH);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: media.viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: sheetH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.emerald200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    book.name,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.chapterCount} capítulos',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      color: AppColors.emerald600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: book.chapterCount,
                      itemBuilder: (_, i) {
                        final ch = i + 1;
                        final selected =
                            bookIndex == _bookIndex && ch == _chapter;
                        return Material(
                          color: selected
                              ? AppColors.emerald600
                              : AppColors.emerald50,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(ctx);
                              _goTo(bookIndex, ch);
                            },
                            child: Center(
                              child: Text(
                                '$ch',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.emerald800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _error!,
            style: TextStyle(fontFamily: 'DM Sans', color: AppColors.emerald700),
          ),
        ),
      );
    }

    if (_bible == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.emerald600),
        ),
      );
    }

    final verses = _book.chapter(_chapter);
    final canPrev = _bookIndex > 0 || _chapter > 1;
    final canNext = _bookIndex < _bible!.books.length - 1 ||
        _chapter < _book.chapterCount;

    return Scaffold(
            appBar: AppBar(
                surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Flexible(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showBookPicker,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${_book.name} $_chapter',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded,
                          color: AppColors.emerald600, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: _showVersionPicker,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.emerald700,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bible!.shortName,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.unfold_more_rounded, size: 16),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Más opciones',
            icon: Icon(Icons.more_vert_rounded, color: AppColors.emerald700),
            onPressed: _showReaderOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              itemCount: verses.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _book.testament == 'AT'
                              ? 'Antiguo Testamento'
                              : 'Nuevo Testamento',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.emerald500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_book.name} · Capítulo $_chapter',
                          style: TextStyle(
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            color: AppColors.emerald900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 2,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.emerald300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final verseNum = i;
                final text = verses[i - 1];
                final hl = _highlightOf(verseNum);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Padding(
                  key: verseNum == _scrollToVerse ? _focusVerseKey : null,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: hl == null
                        ? Colors.transparent
                        : BibleHighlightColors.fill(hl, isDark: isDark),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _showVerseActions(verseNum, text),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: AppColors.emerald100.withValues(alpha: 0.35),
                      highlightColor: AppColors.emerald50.withValues(alpha: 0.25),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$verseNum  ',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: _fontSize * 0.72,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald600,
                                  height: 1.55,
                                ),
                              ),
                              TextSpan(
                                text: text,
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: _fontSize - 1,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: AppColors.emerald900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: AppColors.emerald100),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _NavChip(
                    icon: Icons.chevron_left_rounded,
                    label: 'Anterior',
                    enabled: canPrev,
                    onTap: _prevChapter,
                  ),
                  const Spacer(),
                  Text(
                    '$_chapter / ${_book.chapterCount}',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald600,
                    ),
                  ),
                  const Spacer(),
                  _NavChip(
                    icon: Icons.chevron_right_rounded,
                    label: 'Siguiente',
                    enabled: canNext,
                    onTap: _nextChapter,
                    trailing: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestamentHeader extends StatelessWidget {
  final String label;
  const _TestamentHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.emerald500,
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final BibleBook book;
  final bool selected;
  final VoidCallback onTap;

  const _BookRow({
    required this.book,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: AppColors.emerald50,
      leading: Container(
        width: 40,
        alignment: Alignment.center,
        child: Text(
          book.abbrev,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.emerald700 : AppColors.emerald500,
          ),
        ),
      ),
      title: Text(
        book.name,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.emerald900,
        ),
      ),
      trailing: Text(
        '${book.chapterCount}',
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          color: AppColors.emerald400,
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final String badge;
  final VoidCallback onTap;

  const _VersionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.emerald50
          : Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.emerald300 : AppColors.emerald100,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.menu_book_rounded
                    : Icons.open_in_new_rounded,
                color: AppColors.emerald600,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.emerald600
                      : AppColors.emerald100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.emerald700,
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

class _NavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool trailing;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.emerald700 : AppColors.emerald300;
    return TextButton(
      onPressed: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        children: [
          if (!trailing) Icon(icon, size: 22, color: color),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (trailing) Icon(icon, size: 22, color: color),
        ],
      ),
    );
  }
}
