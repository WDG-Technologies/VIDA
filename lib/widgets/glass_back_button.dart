import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart';

import '../utils/platform_caps.dart';

/// Botón circular de vidrio de iOS 26 para volver o cerrar.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    this.onPressed,
    this.close = false,
    this.dark = false,
  });

  /// Sin valor, vuelve con [Navigator.maybePop].
  final VoidCallback? onPressed;

  /// Una X en lugar de la flecha.
  final bool close;

  /// Vidrio oscuro con icono blanco, para fondos oscuros fijos.
  final bool dark;

  /// Para `AppBar.leading`. Null fuera de iOS o cuando no hay a dónde
  /// volver, para que [AppBar] haga lo de siempre.
  static Widget? leading(BuildContext context, {VoidCallback? onPressed}) {
    if (!PlatformCaps.nativeIosControls) return null;
    final route = ModalRoute.of(context);
    final canGoBack = onPressed != null ||
        (route?.canPop ?? false) ||
        (route?.impliesAppBarDismissal ?? false);
    if (!canGoBack) return null;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassBackButton(
          onPressed: onPressed,
          close: route is PageRoute && route.fullscreenDialog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = CupertinoNativeGlassGroup(
      items: [
        CupertinoNativeGlassGroupItem(
          actionId: 'back',
          icon: CupertinoNativeIcon.symbol(
            close ? CupertinoSymbols.xmark : CupertinoSymbols.chevronLeft,
          ),
        ),
      ],
      onAction: (_) {
        final action = onPressed;
        if (action != null) {
          action();
        } else {
          Navigator.maybePop(context);
        }
      },
    );
    if (!dark) return button;
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: button,
    );
  }
}
