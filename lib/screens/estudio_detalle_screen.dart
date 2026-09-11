import 'package:flutter/material.dart';
import '../data/bible_study.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in.dart';
import 'add_estudio_screen.dart';

class EstudioDetalleScreen extends StatefulWidget {
  final BibleStudy study;

  const EstudioDetalleScreen({super.key, required this.study});

  @override
  State<EstudioDetalleScreen> createState() => _EstudioDetalleScreenState();
}

class _EstudioDetalleScreenState extends State<EstudioDetalleScreen> {
  late BibleStudy _study;

  @override
  void initState() {
    super.initState();
    _study = widget.study;
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar estudio'),
        content: const Text('¿Estás seguro de eliminar este estudio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await BibleStudyService.delete(_study.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEstudioScreen(existing: _study)),
    );
    if (result == true && mounted) {
      final studies = await BibleStudyService.getAll();
      if (!mounted) return;
      final updated =
          studies.where((s) => s.id == _study.id).firstOrNull;
      if (updated != null) {
        setState(() => _study = updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    final s = _study;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded),
            onPressed: _edit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
        ],
      ),
      body: FadeIn(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            s.name,
            style: TextStyle(fontFamily: 'Cormorant Garamond', 
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.emerald900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.emerald500),
              const SizedBox(width: 6),
              Text(
                '${s.date.day} de ${months[s.date.month - 1]} de ${s.date.year}',
                style: TextStyle(fontFamily: 'DM Sans', 
                  fontSize: 14,
                  color: AppColors.emerald600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 18, color: AppColors.emerald700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.book + (s.verses.isNotEmpty ? ' ${s.verses}' : ''),
                    style: TextStyle(fontFamily: 'DM Sans', 
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.emerald800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (s.reflection.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '¿Qué te llevas?',
              style: TextStyle(fontFamily: 'DM Sans', 
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.reflection,
              style: TextStyle(fontFamily: 'DM Sans', 
                fontSize: 15,
                color: AppColors.emerald800,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
