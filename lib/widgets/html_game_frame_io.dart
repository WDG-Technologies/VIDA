import 'package:flutter/material.dart';

/// En móvil/desktop el juego HTML lo carga [WebView] en cada pantalla.
/// Este stub no se usa allí; existe para que el import condicional compile.
class HtmlGameFrame extends StatelessWidget {
  final String title;
  final String assetPath;

  const HtmlGameFrame({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Usa WebView en esta plataforma')),
    );
  }
}
