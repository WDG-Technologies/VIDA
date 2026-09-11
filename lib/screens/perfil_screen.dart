import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/streak.dart';
import '../data/vida_algorithm.dart';
import '../main.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'appearance_screen.dart';
import 'community_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  VidaAssignment? _vida;
  bool _checkingUpdate = false;
  AppUpdateInfo? _update;
  bool _notifEnabled = true;
  int _streak = 0;
  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
    VidaAlgorithm.assignmentChanges.addListener(_load);
  }

  @override
  void dispose() {
    VidaAlgorithm.assignmentChanges.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final a = await VidaAlgorithm.current();
    final notif = await NotificationService.areAwayRemindersEnabled();
    final streak = await StreakService.getCount();
    final best = await StreakService.getBest();
    if (!mounted) return;
    setState(() {
      _vida = a;
      _notifEnabled = notif;
      _streak = streak;
      _bestStreak = best;
    });
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _soon(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editName() async {
    final current = VidaApp.of(context).userName;
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tu nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Cómo quieres que te llamemos',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    if (!mounted) return;
    VidaApp.of(context).setUserName(name);
    _soon('Nombre actualizado');
  }

  Future<void> _toggleNotifs(bool value) async {
    setState(() => _notifEnabled = value);
    await NotificationService.setAwayRemindersEnabled(value);
    if (!mounted) return;
    _soon(
      value
          ? 'Recordatorios activados (si pasas 2 días sin abrir VIDA)'
          : 'Recordatorios desactivados',
    );
  }

  Future<void> _checkUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdateService.checkLatest();
      if (!mounted) return;
      setState(() => _update = info);

      if (info == null) {
        _soon('No se pudo comprobar. Revisa tu conexión.');
        return;
      }
      if (!info.isNewer) {
        _soon(
          'Ya tienes la versión más reciente (${UpdateService.currentLabel}).',
        );
        return;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nueva versión disponible'),
          content: Text(
            '${info.title}\n\n'
            'Tu versión: ${UpdateService.currentLabel}\n'
            'Nueva: ${info.remoteVersion}\n\n'
            'Puedes descargar el APK desde GitHub Releases.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Después'),
            ),
            if (info.apkUrl != null)
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openUrl(info.apkUrl!);
                },
                child: const Text('Descargar APK'),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openUrl(info.htmlUrl);
                },
                child: const Text('Ver release'),
              ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacidad y datos'),
        content: const SingleChildScrollView(
          child: Text(
            'VIDA guarda en tu dispositivo: tu nombre, racha, preferencias, '
            'estudios, resaltados, widgets y señales del versículo VIDA.\n\n'
            'Si usas Comunidad o el Mapa de iglesias, se envían a Firebase '
            '(cuenta, publicaciones, comentarios y datos de iglesias).\n\n'
            'No vendemos datos ni mostramos publicidad.\n\n'
            'Puedes salir de la cuenta de Comunidad desde esa misma pantalla.',
            style: TextStyle(height: 1.45),
          ),
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

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Acerca de VIDA'),
        content: Text(
          'VIDA ${UpdateService.currentLabel}\n'
          'Versión ${UpdateService.currentVersion}+9\n\n'
          'Compañero espiritual diario: Biblia, oración, racha, '
          'evangelismo y comunidad.\n\n'
          'Gratis · Sin publicidad · WDG Technologies',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(UpdateService.releasesUrl);
            },
            child: const Text('Releases'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showDonate() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Apoyar VIDA'),
        content: const Text(
          'Gracias por querer apoyar el proyecto.\n\n'
          'Aún no hay un método de donación activo. Cuando lo habilitemos, '
          'aparecerá aquí. Mientras tanto, compartir la app ya ayuda mucho.',
          style: TextStyle(height: 1.45),
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

  String get _communityStatus {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return 'Sin cuenta (explorar)';
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user.email ?? 'Cuenta conectada';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userName = VidaApp.of(context).userName;
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: _editName,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cs.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName.isEmpty ? 'Sin nombre' : userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Toca para editar tu nombre',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.emerald400),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Stats ──
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Racha',
                    value: '$_streak días',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    icon: Icons.emoji_events_outlined,
                    label: 'Mejor',
                    value: '$_bestStreak días',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    icon: Icons.info_outline_rounded,
                    label: 'Versión',
                    value: UpdateService.currentLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Versículo VIDA ──
            Material(
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => AppShell.goToTab(context, 2),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.emerald600, AppColors.emerald700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.eco_rounded,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            'TU VERSÍCULO VIDA',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _vida == null
                            ? 'Aún no descubierto'
                            : '"${_vida!.text}"',
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _vida?.reference ?? 'Toca para ir a VIDA',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ir a VIDA →',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _section('Preferencias'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.palette_rounded,
                  title: 'Apariencia',
                  subtitle: 'Tema, modo claro/oscuro y acento',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AppearanceScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active_rounded,
                      color: AppColors.emerald600),
                  title: Text(
                    'Recordatorios',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald900,
                    ),
                  ),
                  subtitle: Text(
                    'Aviso si pasas 2 días sin abrir la app',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      color: AppColors.emerald600,
                    ),
                  ),
                  value: _notifEnabled,
                  activeThumbColor: AppColors.emerald600,
                  onChanged: _toggleNotifs,
                ),
              ],
            ),

            _section('Cuenta'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.groups_rounded,
                  title: 'Comunidad',
                  subtitle: _communityStatus,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CommunityScreen()),
                  ),
                ),
              ],
            ),

            _section('Aplicación'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: _checkingUpdate ? null : Icons.system_update_rounded,
                  leading: _checkingUpdate
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.emerald600,
                          ),
                        )
                      : null,
                  title: 'Buscar actualizaciones',
                  subtitle: _update?.isNewer == true
                      ? 'Nueva versión: ${_update!.remoteVersion}'
                      : 'v${UpdateService.currentVersion} · GitHub Releases',
                  onTap: _checkingUpdate ? null : _checkUpdates,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacidad y datos',
                  subtitle: 'Qué se guarda en el dispositivo y en la nube',
                  onTap: _showPrivacy,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Acerca de VIDA',
                  subtitle: UpdateService.currentLabel,
                  onTap: _showAbout,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.favorite_rounded,
                  title: 'Apoyar el proyecto',
                  subtitle: 'Donaciones (próximamente)',
                  onTap: _showDonate,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.open_in_new_rounded,
                  title: 'Código y releases',
                  subtitle: 'GitHub · WDG-Technologies/VIDA',
                  onTap: () => _openUrl(UpdateService.releasesUrl),
                ),
              ],
            ),

            _section('Créditos'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _creditLine(
                      'Desarrollado por',
                      'WDG Technologies',
                      Icons.code_rounded,
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Diseño',
                      'VIDA App',
                      Icons.palette_rounded,
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Biblia',
                      'Reina-Valera 1909 (dominio público)',
                      Icons.menu_book_rounded,
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Evangelízate',
                      'Ray Comfort (Living Waters), Billy Graham, '
                      'Greg Laurie (Harvest), Camino de Romanos, Cru',
                      Icons.campaign_outlined,
                      onTap: () => _openUrl(
                        'https://livingwaters.com/how-to-effectively-share-the-gospel/',
                      ),
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Ayuda de',
                      'Leonardo López',
                      Icons.handshake_rounded,
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Mapas',
                      '© OpenStreetMap contributors',
                      Icons.map_rounded,
                      onTap: () => _openUrl(
                          'https://www.openstreetmap.org/copyright'),
                    ),
                    const Divider(height: 24),
                    _creditLine(
                      'Versión',
                      '${UpdateService.currentLabel} · ${UpdateService.currentVersion}+9',
                      Icons.info_outline_rounded,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                'VIDA ${UpdateService.currentVersion}+9 (${UpdateService.currentLabel})',
                          ),
                        );
                        _soon('Versión copiada');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
          color: AppColors.emerald600,
        ),
      ),
    );
  }

  Widget _creditLine(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.emerald500),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      color: AppColors.emerald500,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald900,
                          ),
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: AppColors.emerald400,
                        ),
                      ],
                    ],
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emerald200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.emerald600),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 10,
              color: AppColors.emerald600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading ??
          (icon != null
              ? Icon(icon, color: AppColors.emerald600)
              : null),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w600,
          color: AppColors.emerald900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          color: AppColors.emerald600,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.emerald400),
      onTap: onTap,
    );
  }
}
