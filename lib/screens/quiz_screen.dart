import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/html_game_frame.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _error = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if ((e.isForMainFrame ?? true) && mounted) {
              setState(() => _error = true);
            }
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadLocalHtml();
    });
  }

  Future<void> _loadLocalHtml() async {
    final c = _controller;
    if (c == null) return;
    try {
      final html = await DefaultAssetBundle.of(context)
          .loadString('games/quiz/index.html');
      await c.loadHtmlString(html);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const HtmlGameFrame(
        title: 'Quiz Bíblico',
        assetPath: 'games/quiz/index.html',
      );
    }

    final controller = _controller!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Bíblico'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_loading)
                LinearProgressIndicator(
                  color: AppColors.emerald600,
                  backgroundColor: AppColors.emerald100,
                ),
              Expanded(child: WebViewWidget(controller: controller)),
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
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
