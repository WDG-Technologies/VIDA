import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/material.dart';

/// Una acción de [GlassCardActions].
class GlassCardAction {
  const GlassCardAction({
    required this.symbol,
    required this.label,
    this.onTap,
  });

  final String symbol;
  final String label;
  final VoidCallback? onTap;
}

/// Fila de botones de vidrio nativo para las tarjetas del inicio.
class GlassCardActions extends StatelessWidget {
  const GlassCardActions({super.key, required this.actions});

  final List<GlassCardAction> actions;

  static const double _height = 36;
  static final _dark = ThemeData(brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark,
      child: Row(
        children: [
          for (final (i, a) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: CupertinoNativeButton.glass(
                expand: true,
                height: _height,
                color: Colors.white,
                onPressed: a.onTap,
                child: Row(
                  children: [
                    CupertinoSymbolImage(a.symbol, size: 14),
                    Text(
                      a.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
