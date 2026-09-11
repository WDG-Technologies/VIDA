import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/bible_data.dart';
import '../data/gallery_images.dart';
import '../theme/app_theme.dart';
import '../utils/download_image.dart';
import '../widgets/responsive_body.dart';

/// Shareable image from a verse already chosen in Biblia.
class VerseImageScreen extends StatefulWidget {
  const VerseImageScreen({
    super.key,
    required this.initialBookIndex,
    required this.initialChapter,
    required this.initialVerse,
    this.initialVerseEnd,
  });

  final int initialBookIndex;
  final int initialChapter;
  final int initialVerse;
  final int? initialVerseEnd;

  @override
  State<VerseImageScreen> createState() => _VerseImageScreenState();
}

class _VerseImageScreenState extends State<VerseImageScreen> {
  final _repaintKey = GlobalKey();
  BibleVersion? _bible;
  bool _loading = true;
  String? _error;

  late int _bookIndex;
  late int _chapter;
  late int _verse;
  late int _verseEnd;

  Uint8List? _bgBytes;
  String? _bgAsset;
  bool _darkBg = true;
  bool _downloading = false;

  bool get _hasBg => _bgBytes != null || _bgAsset != null;

  @override
  void initState() {
    super.initState();
    _bookIndex = widget.initialBookIndex;
    _chapter = widget.initialChapter;
    _verse = widget.initialVerse;
    _verseEnd = widget.initialVerseEnd ?? widget.initialVerse;
    _loadBible();
  }

  Future<void> _loadBible() async {
    try {
      final v = await BibleService.instance.load();
      if (!mounted) return;
      setState(() {
        _bible = v;
        _loading = false;
        _clampSelection();
      });
      if (galleryAssets.isNotEmpty) {
        await _pickTemplate(galleryAssets.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la Biblia';
      });
    }
  }

  void _clampSelection() {
    final books = _bible?.books;
    if (books == null || books.isEmpty) return;
    _bookIndex = _bookIndex.clamp(0, books.length - 1);
    final book = books[_bookIndex];
    _chapter = _chapter.clamp(1, book.chapterCount);
    final verses = book.chapter(_chapter);
    final maxV = verses.isEmpty ? 1 : verses.length;
    _verse = _verse.clamp(1, maxV);
    _verseEnd = _verseEnd.clamp(1, maxV);
    if (_verseEnd < _verse) _verseEnd = _verse;
  }

  BibleBook? get _book =>
      _bible == null
          ? null
          : _bible!.books[_bookIndex.clamp(0, _bible!.books.length - 1)];

  int get _fromVerse => _verse <= _verseEnd ? _verse : _verseEnd;
  int get _toVerse => _verse <= _verseEnd ? _verseEnd : _verse;

  String get _verseText {
    final book = _book;
    if (book == null) return '';
    final verses = book.chapter(_chapter);
    if (verses.isEmpty) return '';
    final parts = <String>[];
    for (var v = _fromVerse; v <= _toVerse; v++) {
      if (v < 1 || v > verses.length) continue;
      parts.add(verses[v - 1]);
    }
    return parts.join(' ');
  }

  String get _reference {
    final book = _book;
    if (book == null) return '';
    if (_fromVerse == _toVerse) {
      return '${book.name} $_chapter:$_fromVerse';
    }
    return '${book.name} $_chapter:$_fromVerse–$_toVerse';
  }

  Future<bool> _isDarkFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final w = img.width;
      final h = img.height;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (data == null || w == 0 || h == 0) return true;

      final x0 = w ~/ 5;
      final y0 = h ~/ 5;
      var sum = 0.0;
      var dark = 0;
      var n = 0;
      for (var y = y0; y < h - y0; y++) {
        for (var x = x0; x < w - x0; x++) {
          final i = (y * w + x) * 4;
          final r = data.getUint8(i) / 255.0;
          final g = data.getUint8(i + 1) / 255.0;
          final b = data.getUint8(i + 2) / 255.0;
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          sum += lum;
          if (lum < 0.55) dark++;
          n++;
        }
      }
      if (n == 0) return true;
      return (sum / n) < 0.58 || dark >= (n * 0.55).round();
    } catch (_) {
      return true;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final dark = await _isDarkFromBytes(bytes);
    if (!mounted) return;
    setState(() {
      _bgBytes = bytes;
      _bgAsset = null;
      _darkBg = dark;
    });
  }

  Future<void> _pickTemplate(String asset) async {
    final data = await rootBundle.load(asset);
    final dark = await _isDarkFromBytes(data.buffer.asUint8List());
    if (!mounted) return;
    setState(() {
      _bgAsset = asset;
      _bgBytes = null;
      _darkBg = dark;
    });
  }

  Future<void> _download() async {
    if (_downloading || !_hasBg || _verseText.isEmpty) return;
    setState(() => _downloading = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Vista no lista');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('No se pudo generar');
      final png = bytes.buffer.asUint8List();
      await downloadPngBytes(
        png,
        'vida_verso_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen descargada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _fondosPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _reference,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.emerald800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Versículo elegido en Biblia',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            color: AppColors.emerald600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Fondo',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.emerald800,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: galleryAssets.length,
          itemBuilder: (_, i) {
            final asset = galleryAssets[i];
            final sel = _bgAsset == asset;
            return GestureDetector(
              onTap: () => _pickTemplate(asset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        sel ? AppColors.emerald600 : AppColors.emerald200,
                    width: sel ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  filterQuality: FilterQuality.low,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _bgBytes == null
                ? 'Usar foto de galería'
                : 'Cambiar foto de galería',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'El color del texto se ajusta al fondo automáticamente.',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            color: AppColors.emerald600,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (!_hasBg || _verseText.isEmpty || _downloading)
              ? null
              : _download,
          icon: _downloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_downloading ? 'Descargando…' : 'Descargar imagen'),
        ),
      ],
    );
  }

  Widget _fondosPanelMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fondo',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.emerald800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: galleryAssets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final asset = galleryAssets[i];
              final sel = _bgAsset == asset;
              return GestureDetector(
                onTap: () => _pickTemplate(asset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          sel ? AppColors.emerald600 : AppColors.emerald200,
                      width: sel ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _bgBytes == null
                ? 'Usar foto de galería'
                : 'Cambiar foto de galería',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'El color del texto se ajusta al fondo automáticamente.',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            color: AppColors.emerald600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Breakpoints.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear imagen'),
        actions: [
          if (!desktop)
            IconButton(
              tooltip: 'Descargar',
              onPressed: (!_hasBg || _verseText.isEmpty || _downloading)
                  ? null
                  : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 640,
                                  maxHeight: 640,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: RepaintBoundary(
                                      key: _repaintKey,
                                      child: _preview(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                            width: 1, color: AppColors.emerald100),
                        SizedBox(
                          width: 400,
                          child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 28),
                              child: _fondosPanel(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        Text(
                          _reference,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.emerald800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Versículo elegido en Biblia',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 12,
                            color: AppColors.emerald600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: RepaintBoundary(
                              key: _repaintKey,
                              child: _preview(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _fondosPanelMobile(),
                      ],
                    ),
    );
  }

  Widget _preview() {
    final verseColor = _darkBg ? Colors.white : Colors.black87;
    final refColor = _darkBg ? Colors.white70 : Colors.black54;
    final len = _verseText.length;
    final fontSize = len > 420
        ? 14.0
        : len > 280
            ? 16.0
            : len > 180
                ? 18.0
                : len > 100
                    ? 20.0
                    : 22.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_bgBytes != null)
          Image.memory(_bgBytes!, fit: BoxFit.cover)
        else if (_bgAsset != null)
          Image.asset(_bgAsset!, fit: BoxFit.cover)
        else
          Container(color: AppColors.emerald100),
        if (_hasBg)
          Container(
            color:
                (_darkBg ? Colors.black : Colors.white).withValues(alpha: 0.28),
          )
        else
          Center(
            child: Icon(Icons.image_outlined,
                size: 48, color: AppColors.emerald400),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        _verseText.isEmpty ? '' : '"$_verseText"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: fontSize,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: !_hasBg ? AppColors.emerald800 : verseColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _reference.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: !_hasBg ? AppColors.emerald600 : refColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
