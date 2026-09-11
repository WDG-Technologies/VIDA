import 'package:flutter/material.dart';
import '../data/evangelizate_data.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';

class EvangelizateDetalleScreen extends StatelessWidget {
  final EvangelizateCategory category;

  const EvangelizateDetalleScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.shortTitle)),
      body: ResponsiveBody(
        maxWidth: Breakpoints.reading,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(category.sections.length, (i) {
            final section = category.sections[i];
            return _buildSection(context, section);
          }),
        ),
      ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, EvangelizateSection section) {
    final hasTitle = section.title.isNotEmpty;
    final hasExplanation = section.explanation.isNotEmpty;
    final hasVerses = section.verses.isNotEmpty;
    final hasTips = section.tips.isNotEmpty;
    final hasSource = section.source.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    section.title,
                    style: TextStyle(fontFamily: 'DM Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasExplanation)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              section.explanation,
              style: TextStyle(fontFamily: 'DM Sans',
                fontSize: 14,
                height: 1.6,
                color: AppColors.emerald800,
              ),
            ),
          ),
        if (hasTips)
          ...List.generate(section.tips.length, (j) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.emerald500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.tips[j],
                      style: TextStyle(fontFamily: 'DM Sans',
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.emerald800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (hasVerses)
          ...List.generate(section.verses.length, (j) {
            final verse = section.verses[j];
            return Padding(
              padding: EdgeInsets.only(
                bottom: j < section.verses.length - 1 ? 10 : 0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.emerald200),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald900.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 16, color: AppColors.emerald600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            verse.reference,
                            style: TextStyle(fontFamily: 'DM Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${verse.text}"',
                      style: TextStyle(fontFamily: 'Cormorant Garamond',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.emerald900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (hasSource)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.emerald500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fuente: ${section.source}',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.emerald600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 24),
        if (!hasTitle && !hasExplanation && !hasVerses && !hasTips)
          const SizedBox.shrink(),
      ],
    );
  }
}
