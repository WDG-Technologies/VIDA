import 'package:flutter/material.dart';
import '../data/consejo.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';

class ConsejoDetalleScreen extends StatelessWidget {
  final Consejo consejo;

  const ConsejoDetalleScreen({super.key, required this.consejo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consejo'),
      ),
      body: ResponsiveBody(
        maxWidth: Breakpoints.reading,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emerald100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                consejo.category,
                style: TextStyle(fontFamily: 'DM Sans', 
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              consejo.title,
              style: TextStyle(fontFamily: 'Cormorant Garamond', 
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              consejo.description,
              style: TextStyle(fontFamily: 'DM Sans', 
                fontSize: 16,
                color: AppColors.emerald800,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emerald200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: 20, color: AppColors.emerald400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      consejo.verse,
                      style: TextStyle(fontFamily: 'Cormorant Garamond', 
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppColors.emerald700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
