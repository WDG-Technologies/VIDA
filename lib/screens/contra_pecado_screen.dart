import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/phrases.dart';
import '../theme/app_theme.dart';

class ContraPecadoScreen extends StatefulWidget {
  const ContraPecadoScreen({super.key});

  @override
  State<ContraPecadoScreen> createState() => _ContraPecadoScreenState();
}

class _ContraPecadoScreenState extends State<ContraPecadoScreen> {
  bool _enabled = false;
  bool _widgetMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('contra_pecado') ?? false;
    if (mounted) setState(() => _enabled = enabled);

    if (enabled) {
      try {
        final widgets = await HomeWidget.getInstalledWidgets();
        final found = widgets.any(
          (w) =>
              (w.androidClassName?.contains('ContraPecadoWidgetProvider') ??
                  false),
        );
        if (mounted) setState(() => _widgetMissing = !found);
      } catch (_) {
        // getInstalledWidgets no disponible en esta plataforma
      }
    }
  }

  Future<void> _toggle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contra_pecado', value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _widgetMissing = false;
    });

    try {
      await HomeWidget.saveWidgetData('contra_pecado', value);

      if (value) {
        final phrase = getTodaysPhrase();
        await HomeWidget.saveWidgetData('phrase', phrase.text);
        await HomeWidget.saveWidgetData('background', phrase.imageAsset);
        await HomeWidget.updateWidget(
          androidName: 'ContraPecadoWidgetProvider',
          iOSName: 'ContraPecadoWidget',
        );
        // Pedir pin si el widget no está instalado (no solo por first_launch_pin).
        var needPin = !(prefs.getBool('first_launch_pin') ?? false);
        try {
          final widgets = await HomeWidget.getInstalledWidgets();
          final found = widgets.any(
            (w) =>
                (w.androidClassName?.contains('ContraPecadoWidgetProvider') ??
                    false),
          );
          needPin = !found;
        } catch (_) {}
        if (needPin) {
          final supported =
              await HomeWidget.isRequestPinWidgetSupported() ?? false;
          if (supported) {
            await HomeWidget.requestPinWidget(
              androidName: 'ContraPecadoWidgetProvider',
            );
          }
          if (mounted && !supported) _showManualPinDialog();
        }
        await prefs.setBool('first_launch_pin', true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Widget activado'),
              duration: Duration(milliseconds: 1200),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        await HomeWidget.saveWidgetData('phrase', '');
        await HomeWidget.saveWidgetData('background', '');
        await HomeWidget.updateWidget(
          androidName: 'ContraPecadoWidgetProvider',
          iOSName: 'ContraPecadoWidget',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Widget desactivado'),
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el widget'),
          duration: Duration(milliseconds: 1600),
        ),
      );
    }
  }

  Future<void> _repin() async {
    try {
      final phrase = getTodaysPhrase();
      await HomeWidget.saveWidgetData('phrase', phrase.text);
      await HomeWidget.saveWidgetData('background', phrase.imageAsset);
      await HomeWidget.updateWidget(
        androidName: 'ContraPecadoWidgetProvider',
        iOSName: 'ContraPecadoWidget',
      );
      final supported =
          await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (supported) {
        await HomeWidget.requestPinWidget(
          androidName: 'ContraPecadoWidgetProvider',
        );
      }
      if (mounted) {
        setState(() => _widgetMissing = false);
        if (!supported) _showManualPinDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widget reinstalado'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo reinstalar el widget'),
          duration: Duration(milliseconds: 1600),
        ),
      );
    }
  }

  void _showManualPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir widget'),
        content: const Text(
          'Mantén presionado un espacio vacío en la pantalla de inicio, '
          'selecciona "Widgets", busca "VIDA" y arrastra "Contra pecado" '
          'a tu pantalla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contra pecado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Widget activo',
                            style: TextStyle(fontFamily: 'DM Sans', 
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Muestra una frase diaria en la pantalla de inicio',
                            style: TextStyle(fontFamily: 'DM Sans', 
                              fontSize: 13,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      activeTrackColor: AppColors.emerald200,
                      activeThumbColor: AppColors.emerald600,
                      onChanged: _toggle,
                    ),
                  ],
                ),
              ),
            ),
            if (_widgetMissing) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber400, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.amber400, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Widget eliminado',
                            style: TextStyle(fontFamily: 'DM Sans', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'El widget ya no está en tu pantalla de inicio.',
                            style: TextStyle(fontFamily: 'DM Sans', 
                              fontSize: 12,
                              color: AppColors.emerald700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _repin,
                      icon: Icon(Icons.add_circle_outline_rounded,
                          size: 18),
                      label: const Text('Añadir'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_enabled) ...[
              const SizedBox(height: 24),
              Text(
                'FRASE DE HOY',
                style: TextStyle(fontFamily: 'DM Sans', 
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: DecorationImage(
                    image: AssetImage(getTodaysPhrase().imageAsset),
                    fit: BoxFit.cover,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    getTodaysPhrase().text,
                    style: TextStyle(fontFamily: 'Cormorant Garamond', 
                      fontSize: 22,
                      color: Colors.white,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emerald200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.emerald500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al desactivar el widget, la frase se oculta pero el espacio en la pantalla de inicio sigue ocupado. Para quitarlo permanentemente, mantén presionado el widget y selecciona "Eliminar".',
                      style: TextStyle(fontFamily: 'DM Sans', 
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.emerald700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
