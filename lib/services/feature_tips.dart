import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Tips de una sola vez (Comunidad, Mapa, etc.).
class FeatureTips {
  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('tip_$key') ?? false);
  }

  static Future<void> markShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tip_$key', true);
  }

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String key,
    required String title,
    required String body,
  }) async {
    if (!await shouldShow(key)) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.45)),
        actions: [
          FilledButton(
            onPressed: () async {
              await markShown(key);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  static Future<void> community(BuildContext context) => showIfNeeded(
        context,
        key: 'community',
        title: 'Comunidad VIDA',
        body:
            'Aquí puedes compartir con otros creyentes.\n\n'
            'Necesitas una cuenta (correo) para publicar. '
            'Sé respetuoso; puedes reportar contenido inapropiado.',
      );

  static Future<void> mapa(BuildContext context) => showIfNeeded(
        context,
        key: 'mapa',
        title: 'Mapa de iglesias',
        body:
            'Encuentra congregaciones cerca de ti.\n\n'
            'La ubicación ayuda a centrar el mapa (opcional). '
            'Puedes unirte a una iglesia o agregar una nueva.',
      );
}

/// Estilo rápido alineado al tema (por si se reusa fuera de dialog).
Color get tipAccent => AppColors.emerald600;
