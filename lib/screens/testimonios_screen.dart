import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in.dart';

class TestimoniosScreen extends StatefulWidget {
  const TestimoniosScreen({super.key});

  @override
  State<TestimoniosScreen> createState() => _TestimoniosScreenState();
}

class _TestimoniosScreenState extends State<TestimoniosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _testimonios = [];
  Map<String, dynamic>? _myTestimonio;
  bool _loading = true;
  Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final hidden = await ReportService.hiddenIds();
      final snap = await _db
          .collection('testimonios')
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      if (!mounted) return;
      setState(() {
        _hidden = hidden;
        _myTestimonio = list.cast<Map<String, dynamic>?>().firstWhere(
              (t) => t?['userId'] == uid,
              orElse: () => null,
            );
        _testimonios = list
            .where((t) => t['userId'] != uid)
            .where((t) => !_hidden
                .contains(ReportService.keyFor('testimonio', '${t['_id']}')))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _canEdit(Map<String, dynamic> t) {
    final created = _asTimestamp(t['createdAt'])?.toDate();
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes < 15;
  }

  Timestamp? _asTimestamp(dynamic value) =>
      value is Timestamp ? value : null;

  Future<void> _openForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _TestimonioFormScreen(
          existing: _myTestimonio,
          canEdit: _myTestimonio != null ? _canEdit(_myTestimonio!) : true,
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Testimonios',
            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.emerald600))
          : RefreshIndicator(
              color: AppColors.emerald600,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _mySection(),
                  const SizedBox(height: 16),
                  if (_testimonios.isNotEmpty) ...[
                    Text('TODOS LOS TESTIMONIOS',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald600)),
                    const SizedBox(height: 8),
                    ..._testimonios.map(_testimonioCard),
                  ] else ...[
                    SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.auto_stories_rounded,
                              size: 56, color: AppColors.emerald300),
                          SizedBox(height: 12),
                          Text('Aún no hay testimonios',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.emerald500)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _mySection() {
    if (_myTestimonio == null) {
      return FadeIn(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.emerald200),
          ),
          color: AppColors.emerald50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.favorite_rounded,
                    size: 40, color: AppColors.emerald400),
                SizedBox(height: 8),
                Text(
                  'Comparte tu testimonio',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald800),
                ),
                SizedBox(height: 4),
                Text(
                  '¿Cómo Cristo transformó tu vida?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.emerald600),
                ),
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openForm,
                  icon: Icon(Icons.edit_rounded, size: 18),
                  label: Text('Escribir testimonio'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final t = _myTestimonio!;
    final editable = _canEdit(t);
    return FadeIn(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: editable ? AppColors.emerald300 : AppColors.emerald200),
        ),
        color: editable
            ? AppColors.emerald50
            : AppColors.emerald50.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded,
                      size: 18, color: AppColors.emerald600),
                  SizedBox(width: 6),
                  Text(
                    t['anonimo'] == true
                        ? 'Anónimo'
                        : (t['nombre'] ?? ''),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.emerald800),
                  ),
                  Spacer(),
                  if (editable)
                    TextButton.icon(
                      onPressed: _openForm,
                      icon: Icon(Icons.edit_rounded, size: 16),
                      label: Text('Editar',
                          style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.emerald600,
                          padding: EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  if (!editable)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emerald200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Publicado',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.emerald700,
                              fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                _formatDate(_asTimestamp(t['createdAt'])),
                style: TextStyle(fontSize: 11, color: AppColors.emerald400),
              ),
              SizedBox(height: 8),
              Text(t['contenido'] ?? '',
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.emerald900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testimonioCard(Map<String, dynamic> t) {
    final isMine = t['userId'] == _auth.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.emerald100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded,
                      size: 16, color: AppColors.emerald500),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t['anonimo'] == true
                          ? 'Anónimo'
                          : (t['nombre'] ?? ''),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.emerald800),
                    ),
                  ),
                  if (isMine)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Tú',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.emerald700,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    IconButton(
                      tooltip: 'Reportar',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.flag_outlined,
                          size: 18, color: AppColors.emerald400),
                      onPressed: () async {
                        final id = '${t['_id']}';
                        await ReportService.submit(
                          targetType: 'testimonio',
                          targetId: id,
                        );
                        if (!mounted) return;
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Gracias. Ocultamos este testimonio aquí.'),
                          ),
                        );
                      },
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                _formatDate(_asTimestamp(t['createdAt'])),
                style: TextStyle(fontSize: 10, color: AppColors.emerald400),
              ),
              SizedBox(height: 6),
              Text(t['contenido'] ?? '',
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.emerald900)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _TestimonioFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final bool canEdit;

  const _TestimonioFormScreen({this.existing, required this.canEdit});

  @override
  State<_TestimonioFormScreen> createState() => _TestimonioFormScreenState();
}

class _TestimonioFormScreenState extends State<_TestimonioFormScreen> {
  final _nombreCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  bool _anonimo = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final t = widget.existing!;
      _nombreCtrl.text = t['nombre'] ?? '';
      _contenidoCtrl.text = t['contenido'] ?? '';
      _anonimo = t['anonimo'] ?? false;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contenido = _contenidoCtrl.text.trim();
    if (contenido.isEmpty || _saving) return;
    if (contenido.length > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo 4000 caracteres')),
      );
      return;
    }

    final nombre = _nombreCtrl.text.trim();
    if (!_anonimo && nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu nombre o marca anónimo')),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final data = {
        'userId': uid,
        'nombre': nombre.isEmpty ? '' : nombre,
        'contenido': contenido,
        'anonimo': _anonimo,
        'createdAt': widget.existing?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existing != null) {
        await FirebaseFirestore.instance
            .collection('testimonios')
            .doc(widget.existing!['_id'] as String)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('testimonios')
            .add(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar testimonio' : 'Nuevo testimonio',
            style: TextStyle(fontWeight: FontWeight.w600)),
                        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.emerald600))
                : Text('Publicar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          TextField(
            controller: _nombreCtrl,
            decoration: InputDecoration(
              labelText: 'Tu nombre',
              hintText: 'Obligatorio si no eres anónimo',
              filled: true,
              fillColor: AppColors.emerald50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _contenidoCtrl,
            maxLines: 10,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Tu testimonio',
              hintText: '¿Cómo Cristo transformó tu vida?',
              hintStyle: TextStyle(color: AppColors.emerald300),
              filled: true,
              fillColor: AppColors.emerald50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Publicar como anónimo',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.emerald800)),
            subtitle: Text(
                'Tu nombre no aparecerá en el testimonio',
                style: TextStyle(fontSize: 12, color: AppColors.emerald500)),
            value: _anonimo,
            activeTrackColor: AppColors.emerald300,
            activeThumbColor: AppColors.emerald600,
            onChanged: (v) => setState(() => _anonimo = v),
          ),
          if (isEditing && !widget.canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emerald100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded,
                        size: 18, color: AppColors.emerald600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya pasaron más de 15 minutos desde la publicación. No puedes editar este testimonio.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.emerald700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
