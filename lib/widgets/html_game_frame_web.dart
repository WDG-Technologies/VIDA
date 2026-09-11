import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../theme/app_theme.dart';

/// Carga un juego HTML de assets en un iframe (Flutter Web).
class HtmlGameFrame extends StatefulWidget {
  final String title;
  final String assetPath;

  const HtmlGameFrame({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<HtmlGameFrame> createState() => _HtmlGameFrameState();
}

class _HtmlGameFrameState extends State<HtmlGameFrame> {
  late final String _viewType;
  var _loading = true;
  var _error = false;
  var _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'vida-html-game-${widget.assetPath.hashCode}-${identityHashCode(this)}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final html =
          await DefaultAssetBundle.of(context).loadString(widget.assetPath);
      if (!mounted) return;
      if (!_registered) {
        ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
          final iframe = web.HTMLIFrameElement()
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          iframe.setAttribute(
            'sandbox',
            'allow-scripts allow-same-origin allow-forms',
          );
          iframe.srcdoc = html.toJS;
          iframe.onLoad.listen((_) {
            if (mounted) setState(() => _loading = false);
          });
          return iframe;
        });
        _registered = true;
      }
      setState(() {
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (!_error && _registered)
              HtmlElementView(viewType: _viewType)
            else if (!_error)
              const SizedBox.expand(),
            if (_loading)
              LinearProgressIndicator(
                color: AppColors.emerald600,
                backgroundColor: AppColors.emerald100,
              ),
            if (_error)
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bug_report_rounded,
                            size: 48, color: AppColors.emerald400),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo cargar el juego',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _error = false;
                              _loading = true;
                            });
                            _load();
                          },
                          child: const Text('Reintentar'),
                        ),
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
}
