import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fav.dart';
import '../theme/app_theme.dart';

class FavoritoScreen extends StatefulWidget {
  const FavoritoScreen({super.key});

  @override
  State<FavoritoScreen> createState() => _FavoritoScreenState();
}

class _FavoritoScreenState extends State<FavoritoScreen> {
  bool _enabled = false;
  bool _widgetMissing = false;
  int? _selectedIndex;
  String? _customBgPath;
  bool _darkBg = false;

  static const _bgPrefsKey = 'fav_bg_path';
  static const _darkPrefsKey = 'fav_dark_bg';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('favorito') ?? false;
    final selected = prefs.getInt('fav_index');
    final bg = prefs.getString(_bgPrefsKey);
    final bgExists = bg != null && File(bg).existsSync();
    var dark = prefs.getBool(_darkPrefsKey) ?? false;
    if (bgExists && !prefs.containsKey(_darkPrefsKey)) {
      dark = await _isDarkBackground(File(bg));
      await prefs.setBool(_darkPrefsKey, dark);
      await HomeWidget.saveWidgetData('fav_dark_bg', dark);
    }
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _selectedIndex = selected;
        _customBgPath = bgExists ? bg : null;
        _darkBg = bgExists && dark;
      });
    }

    if (enabled) {
      try {
        final widgets = await HomeWidget.getInstalledWidgets();
        final found = widgets.any(
          (w) =>
              (w.androidClassName?.contains('FavoritoWidgetProvider') ??
                  false),
        );
        if (mounted) setState(() => _widgetMissing = !found);
      } catch (_) {}
    }
  }

  Future<Directory> _bgDir() => getApplicationSupportDirectory();

  Future<void> _deleteOldBgs({String? keepPath}) async {
    try {
      final dir = await _bgDir();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;
        if (!name.startsWith('favorito_bg')) continue;
        if (keepPath != null && entity.path == keepPath) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Samples the center; dark if average is low or most pixels are dim.
  Future<bool> _isDarkBackground(File file) async {
    try {
      final bytes = await file.readAsBytes();
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
      if (data == null || w == 0 || h == 0) return false;

      final x0 = w ~/ 5;
      final y0 = h ~/ 5;
      final x1 = w - x0;
      final y1 = h - y0;
      var sum = 0.0;
      var darkPixels = 0;
      var n = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          final r = data.getUint8(i) / 255.0;
          final g = data.getUint8(i + 1) / 255.0;
          final b = data.getUint8(i + 2) / 255.0;
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          sum += lum;
          if (lum < 0.55) darkPixels++;
          n++;
        }
      }
      if (n == 0) return false;
      final avg = sum / n;
      return avg < 0.58 || darkPixels >= (n * 0.55).round();
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshWidget() async {
    if (_enabled && _selectedIndex != null) {
      await _pushToWidget(_selectedIndex!);
    } else {
      await HomeWidget.saveWidgetData('fav_bg_path', _customBgPath ?? '');
      await HomeWidget.saveWidgetData('fav_dark_bg', _darkBg);
      await HomeWidget.updateWidget(
        androidName: 'FavoritoWidgetProvider',
        iOSName: 'FavoritoWidget',
      );
    }
  }

  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 78,
    );
    if (picked == null) return;

    try {
      final dir = await _bgDir();
      final dest = File(
        '${dir.path}/favorito_bg_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(picked.path).copy(dest.path);
      await _deleteOldBgs(keepPath: dest.path);
      final dark = await _isDarkBackground(dest);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bgPrefsKey, dest.path);
      await prefs.setBool(_darkPrefsKey, dark);
      if (!mounted) return;
      setState(() {
        _customBgPath = dest.path;
        _darkBg = dark;
      });
      await _refreshWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fondo del widget actualizado'),
          duration: Duration(milliseconds: 1400),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo usar esa imagen')),
      );
    }
  }

  Future<void> _resetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgPrefsKey);
    await prefs.setBool(_darkPrefsKey, false);
    await HomeWidget.saveWidgetData('fav_bg_path', '');
    await HomeWidget.saveWidgetData('fav_dark_bg', false);
    await _deleteOldBgs();
    if (!mounted) return;
    setState(() {
      _customBgPath = null;
      _darkBg = false;
    });
    await _refreshWidget();
  }

  Future<void> _toggle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('favorito', value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _widgetMissing = false;
    });

    await HomeWidget.saveWidgetData('favorito', value);

    try {
      if (value) {
        final index = _selectedIndex ?? 0;
        await prefs.setInt('fav_index', index);
        if (mounted) setState(() => _selectedIndex = index);
        if (_customBgPath != null) {
          await HomeWidget.saveWidgetData('fav_bg_path', _customBgPath);
          await HomeWidget.saveWidgetData('fav_dark_bg', _darkBg);
        }
        await _pushToWidget(index);
        final firstFavPin = prefs.getBool('first_launch_fav_pin') ?? false;
        if (!firstFavPin) {
          await prefs.setBool('first_launch_fav_pin', true);
          final supported =
              await HomeWidget.isRequestPinWidgetSupported() ?? false;
          if (supported) {
            await HomeWidget.requestPinWidget(
              androidName: 'FavoritoWidgetProvider',
            );
          }
          if (mounted && !supported) _showManualPinDialog();
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        await HomeWidget.saveWidgetData('fav_ref', '');
        await HomeWidget.saveWidgetData('fav_verse', '');
        await HomeWidget.updateWidget(
          androidName: 'FavoritoWidgetProvider',
          iOSName: 'FavoritoWidget',
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _selectVerse(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fav_index', index);
    if (!mounted) return;
    setState(() => _selectedIndex = index);

    if (_enabled) {
      await _pushToWidget(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Versículo actualizado: ${favVerses[index].referencia}'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    }
  }

  Future<void> _pushToWidget(int index) async {
    final verse = favVerses[index];
    await HomeWidget.saveWidgetData('fav_ref', verse.referencia);
    await HomeWidget.saveWidgetData('fav_verse', verse.versiculo);
    await HomeWidget.saveWidgetData('fav_bg_path', _customBgPath ?? '');
    await HomeWidget.saveWidgetData('fav_dark_bg', _darkBg);
    await HomeWidget.updateWidget(
      androidName: 'FavoritoWidgetProvider',
      iOSName: 'FavoritoWidget',
    );
  }

  Future<void> _repin() async {
    if (_selectedIndex == null) return;
    await _pushToWidget(_selectedIndex!);
    final supported =
        await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (supported) {
      await HomeWidget.requestPinWidget(
        androidName: 'FavoritoWidgetProvider',
      );
    }
    if (mounted) {
      setState(() => _widgetMissing = false);
      if (!supported) _showManualPinDialog();
    }
  }

  void _showManualPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir widget'),
        content: const Text(
          'Mantén presionado un espacio vacío en la pantalla de inicio, '
          'selecciona "Widgets", busca "VIDA" y arrastra "Widget favorito" '
          'a tu pantalla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  FavVerse? get _selectedVerse =>
      _selectedIndex != null ? favVerses[_selectedIndex!] : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget favorito')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Widget activo',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emerald900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Muestra un versículo en la pantalla de inicio',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 13,
                                  color: AppColors.emerald600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          activeTrackColor: AppColors.emerald200,
                          activeThumbColor: AppColors.emerald600,
                          onChanged: _toggle,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_widgetMissing) ...[
                  const SizedBox(height: 12),
                  _warningBanner(),
                ],
                if (_enabled && _selectedVerse != null) ...[
                  const SizedBox(height: 24),
                  _previewCard(),
                  const SizedBox(height: 12),
                  _backgroundControls(),
                ],
                const SizedBox(height: 24),
                Text(
                  'ELIGE UN VERSÍCULO',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald600,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(favVerses.length, (i) {
                  final verse = favVerses[i];
                  final selected = _selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: selected
                          ? AppColors.emerald100
                          : AppColors.emerald50,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _enabled ? () => _selectVerse(i) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      verse.referencia,
                                      style: TextStyle(
                                        fontFamily: 'DM Sans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.emerald900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      verse.versiculo,
                                      style: TextStyle(
                                        fontFamily: 'DM Sans',
                                        fontSize: 12,
                                        color: AppColors.emerald700,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.emerald600, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.emerald500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selecciona un versículo y, si quieres, cambia el fondo del widget con una foto tuya.',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.emerald700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickBackground,
            icon: Icon(Icons.photo_library_rounded, size: 18),
            label: Text(
              _customBgPath == null ? 'Elegir fondo' : 'Cambiar fondo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emerald700,
              side: BorderSide(color: AppColors.emerald400),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_customBgPath != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Usar fondo original',
            onPressed: _resetBackground,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.emerald50,
              foregroundColor: AppColors.emerald700,
            ),
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ],
    );
  }

  Widget _warningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.emerald50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber400, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.amber400, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Widget eliminado',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'El widget ya no está en tu pantalla de inicio.',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: AppColors.emerald700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _repin,
            icon: Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Añadir'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald600,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final v = _selectedVerse!;
    final bg = _customBgPath;
    final dark = bg != null && _darkBg;
    final verseColor = dark ? Colors.white : Colors.black87;
    final refColor = dark ? Colors.white70 : Colors.black54;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: Stack(
          children: [
            Positioned.fill(
              child: bg != null
                  ? Image.file(
                      File(bg),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'widget-fav.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'widget-fav.png',
                      fit: BoxFit.cover,
                    ),
            ),
            // Light default needs a veil; custom uses auto text contrast instead.
            if (bg == null)
              Container(color: Colors.white.withValues(alpha: 0.69))
            else
              Container(
                color: (dark ? Colors.black : Colors.white)
                    .withValues(alpha: 0.22),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '"${v.versiculo}"',
                      style: TextStyle(
                        fontFamily: 'Cormorant Garamond',
                        fontSize: 18,
                        color: verseColor,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      v.referencia,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                        color: refColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
