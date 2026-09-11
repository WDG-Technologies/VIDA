import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Avatar del usuario: inicial o «Formita» (Blobatar).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  static String seedFor(String name) {
    final t = name.trim();
    return t.isEmpty ? 'vida' : t;
  }

  static String initialFor(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return String.fromCharCode(t.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final useFormita = ThemeController.instance.useFormita;
        if (!useFormita) return _initial(context);
        return _formita(context);
      },
    );
  }

  Widget _initial(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primary;
    final fg = foregroundColor ?? Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initialFor(name),
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _formita(BuildContext context) {
    final size = (radius * 2).round().clamp(32, 256);
    final seed = Uri.encodeComponent(seedFor(name));
    final url =
        'https://blobatar.dev/avatar/$seed?size=$size&background=circle&gen=2';

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: SvgPicture.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => _formitaPlaceholder(context),
          errorBuilder: (_, __, ___) => _initial(context),
        ),
      ),
    );
  }

  Widget _formitaPlaceholder(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppColors.emerald100,
      alignment: Alignment.center,
      child: SizedBox(
        width: radius * 0.7,
        height: radius * 0.7,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foregroundColor ?? AppColors.emerald600,
        ),
      ),
    );
  }
}
