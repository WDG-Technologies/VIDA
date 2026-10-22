import 'package:flutter/material.dart';

import '../utils/platform_caps.dart';
import 'glass_card_actions.dart';

class VidaVerseCard extends StatelessWidget {
  final String verseText;
  final String reference;
  final bool saved;
  final String eyebrow;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  const VidaVerseCard({
    super.key,
    required this.verseText,
    required this.reference,
    this.saved = false,
    this.eyebrow = 'TU VERSÍCULO · VIDA',
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.onShare,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -45,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    '"$verseText"',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 17,
                      color: Colors.white,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '— $reference',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                if (PlatformCaps.nativeIosControls)
                  GlassCardActions(
                    actions: [
                      GlassCardAction(
                        symbol: 'square.and.arrow.up',
                        label: 'Compartir',
                        onTap: onShare,
                      ),
                      GlassCardAction(
                        symbol: saved ? 'bookmark.fill' : 'bookmark',
                        label: saved ? 'Guardado' : 'Guardar',
                        onTap: onSave,
                      ),
                    ],
                  )
                else
                Row(
                  children: [
                    _ActionChip(
                      icon: Icons.share_rounded,
                      label: 'Compartir',
                      onTap: onShare,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Guardado' : 'Guardar',
                      onTap: onSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}