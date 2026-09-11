import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class RiegaScreen extends StatefulWidget {
  const RiegaScreen({super.key});

  @override
  State<RiegaScreen> createState() => _RiegaScreenState();
}

class _RiegaScreenState extends State<RiegaScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('RiegaChannel',
          onMessageReceived: _onStateChanged)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            if (mounted) setState(() => _loading = false);
            await _restoreState();
          },
          onWebResourceError: (e) {
            if ((e.isForMainFrame ?? true) && mounted) setState(() => _error = true);
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadLocalHtml();
    });
  }

  Future<void> _loadLocalHtml() async {
    try {
      final html = await DefaultAssetBundle.of(context)
          .loadString('games/riega/index.html');
      if (!mounted) return;
      await _controller.loadHtmlString(html,
          baseUrl: 'https://riega-game.local/');
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _onStateChanged(JavaScriptMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('riega_game_state', message.message);
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getString('riega_game_state');
    if (saved != null) {
      // jsonEncode produces a safe JS string literal (quotes + escapes).
      await _controller.runJavaScript('restoreFlutterState(${jsonEncode(saved)})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riega y Crece'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_loading)
                  LinearProgressIndicator(
                    color: AppColors.emerald600,
                    backgroundColor: AppColors.emerald100,
                  ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
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
                              fontSize: 16,
                              color: AppColors.emerald700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _error = false;
                              _loading = true;
                            });
                            _loadLocalHtml();
                          },
                          icon: Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
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
