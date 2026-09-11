import 'package:flutter/material.dart';
import '../data/gallery_images.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';
import 'image_editor_screen.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Plantillas',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.emerald600,
          ),
        ),
      ),
      body: ResponsiveBody(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = Breakpoints.galleryColumns(w);
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final cellW = w / cols;
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: galleryAssets.length,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageEditorScreen(
                        imageAsset: galleryAssets[i],
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      galleryAssets[i],
                      fit: BoxFit.cover,
                      cacheWidth: (cellW * dpr).round().clamp(200, 900),
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
