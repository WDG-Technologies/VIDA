import 'package:flutter/material.dart';
import '../data/bible_study.dart';

class AddEstudioScreen extends StatefulWidget {
  final BibleStudy? existing;

  const AddEstudioScreen({super.key, this.existing});

  @override
  State<AddEstudioScreen> createState() => _AddEstudioScreenState();
}

class _AddEstudioScreenState extends State<AddEstudioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bookCtrl = TextEditingController();
  final _versesCtrl = TextEditingController();
  final _reflectionCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _date = e.date;
      _bookCtrl.text = e.book;
      _versesCtrl.text = e.verses;
      _reflectionCtrl.text = e.reflection;
    }
    _updateDateText();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bookCtrl.dispose();
    _versesCtrl.dispose();
    _reflectionCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _updateDateText() {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    _dateCtrl.text =
        '${_date.day} de ${months[_date.month - 1]} de ${_date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _updateDateText();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final study = BibleStudy(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        date: _date,
        book: _bookCtrl.text.trim(),
        verses: _versesCtrl.text.trim(),
        reflection: _reflectionCtrl.text.trim(),
      );

      if (widget.existing != null) {
        await BibleStudyService.update(study);
      } else {
        await BibleStudyService.save(study);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el estudio')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      fontSize: 14,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Editar estudio' : 'Estudio'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Título del estudio',
                hintStyle: hintStyle,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Fecha',
                hintText: 'Selecciona una fecha',
                hintStyle: hintStyle,
                suffixIcon: const Icon(Icons.calendar_today_rounded),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bookCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Libro',
                hintText: 'Ej: Juan, Romanos',
                hintStyle: hintStyle,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _versesCtrl,
              decoration: InputDecoration(
                labelText: 'Versículos (opcional)',
                hintText: 'Ej: 3:16-18',
                hintStyle: hintStyle,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reflectionCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: '¿Qué te llevas?',
                hintText: 'Tus reflexiones del estudio',
                hintStyle: hintStyle,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
