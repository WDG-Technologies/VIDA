import 'package:flutter/material.dart';
import '../data/consejo.dart';
import '../data/consejos_data.dart';
import '../data/vida_signals.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';
import 'consejo_detalle_screen.dart';

class SituacionDificilScreen extends StatefulWidget {
  const SituacionDificilScreen({super.key});

  @override
  State<SituacionDificilScreen> createState() => _SituacionDificilScreenState();
}

class _SituacionDificilScreenState extends State<SituacionDificilScreen> {
  static const _categories = [
    'Todos',
    'Ansiedad',
    'Perdón',
    'Fe',
    'Relaciones',
    'Finanzas',
    'Depresión',
  ];

  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Consejo> get _filteredConsejos {
    var list = allConsejos;
    if (_selectedCategory != 'Todos') {
      list = list.where((c) => c.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.category.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredConsejos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Situación difícil'),
      ),
      body: ResponsiveBody(
        maxWidth: 800,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar consejos…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: AppColors.emerald400),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 18, color: AppColors.emerald400),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categories.map((cat) {
                final selected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.emerald600
                            : AppColors.emerald50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(fontFamily: 'DM Sans', 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? Colors.white : AppColors.emerald700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No se encontraron consejos para tu búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'DM Sans', 
                          fontSize: 14,
                          color: AppColors.emerald500,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final c = results[i];
                      return _ConsejoCard(
                        consejo: c,
                        onTap: () {
                          VidaSignals.trackCategory(c.category);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConsejoDetalleScreen(consejo: c),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ConsejoCard extends StatelessWidget {
  final Consejo consejo;
  final VoidCallback onTap;

  const _ConsejoCard({required this.consejo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emerald200, width: 1),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.emerald100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      consejo.category,
                      style: TextStyle(fontFamily: 'DM Sans', 
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.emerald400),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                consejo.title,
                style: TextStyle(fontFamily: 'Cormorant Garamond', 
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                consejo.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'DM Sans', 
                  fontSize: 13,
                  color: AppColors.emerald700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
