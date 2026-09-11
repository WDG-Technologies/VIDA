import 'package:flutter/material.dart';

/// Anchos y columnas adaptativos para web/desktop.
class Breakpoints {
  Breakpoints._();

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) => widthOf(context) >= 700;
  static bool isDesktop(BuildContext context) => widthOf(context) >= 1000;

  /// Ancho máximo de dashboards/herramientas.
  static double contentMaxWidth(BuildContext context) {
    final w = widthOf(context);
    if (w >= 1400) return 1320;
    if (w >= 1100) return 1180;
    return w;
  }

  /// Lectura / feeds / formularios (evita líneas kilométricas en PC).
  static const double reading = 720;
  static const double form = 560;
  static const double feed = 680;

  static int toolColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  static double toolAspect(double width) {
    if (width >= 1100) return 1.35;
    if (width >= 720) return 1.2;
    return 0.95;
  }

  static int arcadeColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 700) return 3;
    return 2;
  }

  static double arcadeAspect(double width) {
    if (width >= 1100) return 1.45;
    if (width >= 700) return 1.25;
    return 1.05;
  }

  static int galleryColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    return 2;
  }
}

/// Centra y limita el contenido; en desktop usa casi todo el ancho.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  static bool isWide(BuildContext context) => Breakpoints.isDesktop(context);

  @override
  Widget build(BuildContext context) {
    final max = maxWidth ?? Breakpoints.contentMaxWidth(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
