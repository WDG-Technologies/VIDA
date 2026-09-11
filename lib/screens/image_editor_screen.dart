import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/verse_picker_sheet.dart';

enum _TextAlign { top, center, bottom }

class ImageEditorScreen extends StatefulWidget {
  final String imageAsset;
  final String? initialText;
  const ImageEditorScreen({
    super.key,
    required this.imageAsset,
    this.initialText,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final _textController = TextEditingController();
  final _repaintKey = GlobalKey();
  bool _capturing = false;
  String _text = '';
  Color _textColor = Colors.white;
  double _fontSize = 32;
  _TextAlign _textAlign = _TextAlign.bottom;

  List<Color> get _colors => [
    Colors.white,
    Colors.black,
    AppColors.emerald100,
    AppColors.emerald300,
    AppColors.emerald500,
    AppColors.emerald700,
    AppColors.amber400,
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialText?.trim();
    if (t != null && t.isNotEmpty) {
      _text = t;
      _textController.text = t;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _captureAndShare() async {
    if (_capturing || _text.isEmpty) return;
    setState(() => _capturing = true);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render not ready');

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vida_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen compartida'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('MissingPluginException')
            ? 'Compartir no disponible. Prueba: flutter clean && flutter pub get'
            : 'Error al compartir: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar imagen',
          style: TextStyle(fontFamily: 'Cormorant Garamond', 
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: (_text.isEmpty || _capturing) ? null : _captureAndShare,
            icon: _capturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.share_rounded),
            tooltip: 'Compartir',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(widget.imageAsset, fit: BoxFit.cover),
                      if (_text.isNotEmpty)
                        Positioned(
                          left: 18,
                          right: 18,
                          top: 24,
                          bottom: 24,
                          child: Align(
                            alignment: _textAlign == _TextAlign.top
                                ? Alignment.topCenter
                                : _textAlign == _TextAlign.center
                                    ? Alignment.center
                                    : Alignment.bottomCenter,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: _textAlign == _TextAlign.top
                                      ? Alignment.topCenter
                                      : _textAlign == _TextAlign.center
                                          ? Alignment.center
                                          : Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Text(
                                      _text,
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontFamily: 'Cormorant Garamond',
                                        fontSize: _fontSize,
                                        color: _textColor,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black54,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: AppColors.emerald100)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: TextStyle(color: AppColors.emerald400),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald600),
                        onPressed: () {
                          setState(
                            () => _text = _textController.text.trim(),
                          );
                        },
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => setState(() => _text = v.trim()),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.emerald700,
                      ),
                      onPressed: () async {
                        final picked = await showVersePickerSheet(context);
                        if (picked == null || !mounted) return;
                        setState(() {
                          _textController.text = picked.formatted;
                          _text = picked.formatted;
                        });
                      },
                      icon: Icon(Icons.menu_book_rounded, size: 16),
                      label: Text(
                        'Agregar versículo',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _alignBtn(Icons.vertical_align_top, _TextAlign.top),
                        const SizedBox(width: 4),
                        _alignBtn(Icons.vertical_align_center, _TextAlign.center),
                        const SizedBox(width: 4),
                        _alignBtn(Icons.vertical_align_bottom, _TextAlign.bottom),
                        const SizedBox(width: 12),
                        ..._colors.map(
                          (c) => GestureDetector(
                            onTap: () => setState(() => _textColor = c),
                            child: Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _textColor == c
                                      ? AppColors.emerald600
                                      : AppColors.emerald200,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _sizeBtn(24, 'S'),
                        const SizedBox(width: 4),
                        _sizeBtn(32, 'M'),
                        const SizedBox(width: 4),
                        _sizeBtn(44, 'L'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alignBtn(IconData icon, _TextAlign align) {
    final selected = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.emerald500 : AppColors.emerald200,
          ),
        ),
        child: Icon(icon,
            size: 18,
            color: selected ? AppColors.emerald800 : AppColors.emerald600),
      ),
    );
  }

  Widget _sizeBtn(double size, String label) {
    final selected = _fontSize == size;
    return GestureDetector(
      onTap: () => setState(() => _fontSize = size),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.emerald500 : AppColors.emerald200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.emerald800 : AppColors.emerald600,
          ),
        ),
      ),
    );
  }
}
