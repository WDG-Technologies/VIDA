import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';
import '../utils/download_image.dart';
import '../widgets/responsive_body.dart';
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

  Future<void> _captureAndDownload() async {
    if (_capturing || _text.isEmpty) return;
    setState(() => _capturing = true);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render not ready');

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final bytes = byteData.buffer.asUint8List();
      await downloadPngBytes(bytes, 'vida_${DateTime.now().millisecondsSinceEpoch}.png');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen descargada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Widget _previewCanvas({double maxSide = 560}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxSide, maxHeight: maxSide),
      child: AspectRatio(
        aspectRatio: 1,
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
    );
  }

  Widget _toolsPanel({required bool scrollable}) {
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Texto',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.emerald800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Escribe tu mensaje...',
            hintStyle: TextStyle(color: AppColors.emerald400),
            suffixIcon: IconButton(
              icon: Icon(Icons.check_circle_rounded,
                  color: AppColors.emerald600),
              onPressed: () {
                setState(() => _text = _textController.text.trim());
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
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text(
              'Agregar versículo',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Posición',
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
            _alignBtn(Icons.vertical_align_top, _TextAlign.top),
            const SizedBox(width: 6),
            _alignBtn(Icons.vertical_align_center, _TextAlign.center),
            const SizedBox(width: 6),
            _alignBtn(Icons.vertical_align_bottom, _TextAlign.bottom),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Color',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.emerald800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() => _textColor = c),
                child: Container(
                  width: 32,
                  height: 32,
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
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tamaño',
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
            _sizeBtn(24, 'S'),
            const SizedBox(width: 6),
            _sizeBtn(32, 'M'),
            const SizedBox(width: 6),
            _sizeBtn(44, 'L'),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (_text.isEmpty || _capturing) ? null : _captureAndDownload,
          icon: _capturing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_capturing ? 'Descargando…' : 'Descargar imagen'),
        ),
      ],
    );

    if (!scrollable) return panel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Breakpoints.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar imagen',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald600,
          ),
        ),
        actions: [
          if (!desktop)
            IconButton(
              onPressed:
                  (_text.isEmpty || _capturing) ? null : _captureAndDownload,
              icon: _capturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Descargar',
            ),
        ],
      ),
      body: desktop
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _previewCanvas(maxSide: 640),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: AppColors.emerald100),
                SizedBox(
                  width: 380,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: _toolsPanel(scrollable: true),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _previewCanvas(maxSide: 560),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                          top: BorderSide(color: AppColors.emerald100)),
                    ),
                    child: _toolsPanel(scrollable: false),
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
        width: 40,
        height: 40,
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
        width: 40,
        height: 40,
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
