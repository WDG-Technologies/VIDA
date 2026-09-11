import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/community_push.dart';
import '../services/feature_tips.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class CommunityScreen extends StatefulWidget {
  final String? focusPostId;

  const CommunityScreen({super.key, this.focusPostId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    // userChanges also fires on link/profile reload (authStateChanges often does not).
    _authSub = _auth.userChanges().listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FeatureTips.community(context);
      CommunityPushService.markAllRead();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _refreshAuth() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAnonymous = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (!isAnonymous)
            IconButton(
              tooltip: 'Cuenta',
              onPressed: () => _openAccountSheet(context, user),
              icon: Icon(Icons.manage_accounts_rounded,
                  color: AppColors.emerald700, size: 24),
            ),
        ],
      ),
      body: isAnonymous
          ? _AuthView(onAuthed: _refreshAuth)
          : _FeedView(focusPostId: widget.focusPostId),
    );
  }

  Future<void> _openAccountSheet(BuildContext context, User user) async {
    final name = user.displayName?.trim();
    final email = user.email?.trim() ?? '';
    var pushOn = await CommunityPushService.isEnabled();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: UserAvatar(
                        name: (name != null && name.isNotEmpty)
                            ? name
                            : 'Usuario',
                        radius: 22,
                      ),
                      title: Text(
                        (name != null && name.isNotEmpty) ? name : 'Cuenta',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: email.isNotEmpty
                          ? Text(email,
                              style: TextStyle(color: cs.onSurfaceVariant))
                          : null,
                    ),
                    const Divider(height: 8),
                    SwitchListTile.adaptive(
                      secondary: Icon(Icons.notifications_active_outlined,
                          color: AppColors.emerald600),
                      title: const Text('Avisos de Comunidad'),
                      subtitle: const Text(
                        'Likes y respuestas (con la app abierta o al volver)',
                      ),
                      value: pushOn,
                      onChanged: (v) async {
                        await CommunityPushService.setEnabled(v);
                        setLocal(() => pushOn = v);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded,
                          color: AppColors.emerald600),
                      title: const Text('Sobre Comunidad'),
                      subtitle: const Text(
                        'Comparte con respeto. Puedes reportar o eliminar tus posts.',
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog<void>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Comunidad VIDA'),
                            content: const Text(
                              'Publica con respeto. Puedes eliminar tus propias '
                              'publicaciones y reportar contenido inapropiado.',
                              style: TextStyle(height: 1.45),
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout_rounded,
                          color: Colors.red.shade400),
                      title: Text('Cerrar sesión',
                          style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Vuelves a la pantalla de inicio de sesión'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await _auth.signOut();
                          await _auth.signInAnonymously();
                        } catch (_) {}
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────── Auth View ───────────────

class _AuthView extends StatefulWidget {
  const _AuthView({required this.onAuthed});

  final VoidCallback onAuthed;

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView>
    with SingleTickerProviderStateMixin {
  static const _domains = <String>[
    '@gmail.com',
    '@outlook.com',
    '@hotmail.com',
    '@live.com',
    '@live.com.mx',
    '@yahoo.com',
    '@icloud.com',
    '@proton.me',
  ];

  late final TabController _tabCtrl;
  final _nameCtrl = TextEditingController();
  final _emailLocalCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _domain = _domains.first;
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final splashName = VidaApp.of(context).userName.trim();
      if (splashName.isNotEmpty && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = splashName;
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _emailLocalCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _fullEmail {
    var local = _emailLocalCtrl.text.trim().toLowerCase();
    if (local.contains('@')) {
      local = local.split('@').first;
    }
    local = local.replaceAll(RegExp(r'\s+'), '');
    return '$local$_domain';
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _fullEmail;
    final pass = _passCtrl.text.trim();
    final isRegister = _tabCtrl.index == 1;
    final local = _emailLocalCtrl.text.trim();

    if (local.isEmpty || pass.length < 6) {
      _snack('Correo y contraseña (mín 6 caracteres)');
      return;
    }
    if (isRegister && name.isEmpty) {
      _snack('Ingresa tu nombre');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser;
      final credential =
          EmailAuthProvider.credential(email: email, password: pass);

      if (isRegister) {
        var createdOrLinked = false;
        if (current != null && current.isAnonymous) {
          try {
            await current.linkWithCredential(credential);
            createdOrLinked = true;
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use' ||
                e.code == 'credential-already-in-use') {
              await auth.signInWithEmailAndPassword(
                  email: email, password: pass);
            } else {
              rethrow;
            }
          }
        } else {
          await auth.createUserWithEmailAndPassword(
              email: email, password: pass);
          createdOrLinked = true;
        }
        final user = auth.currentUser;
        // Solo renombrar en cuenta nueva/vinculada; no pisar perfil existente.
        if (createdOrLinked && user != null && name.isNotEmpty) {
          await user.updateDisplayName(name);
          await user.reload();
        } else if (user != null &&
            (user.displayName == null || user.displayName!.trim().isEmpty) &&
            name.isNotEmpty) {
          await user.updateDisplayName(name);
          await user.reload();
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
        if (!mounted) return;
        final user = auth.currentUser;
        final fallbackName = name.isNotEmpty
            ? name
            : VidaApp.of(context).userName.trim();
        if (user != null &&
            (user.displayName == null || user.displayName!.trim().isEmpty) &&
            fallbackName.isNotEmpty) {
          await user.updateDisplayName(fallbackName);
          await user.reload();
        }
      }

      // Force parent rebuild — linking anonymous users often skips authStateChanges.
      await auth.currentUser?.reload();
      await auth.currentUser?.getIdToken(true);
      if (mounted) widget.onAuthed();
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Error de autenticación');
    } catch (e) {
      _snack('Error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _tabCtrl.index == 1;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_rounded,
                size: 64, color: AppColors.emerald400),
            const SizedBox(height: 12),
            Text('Comunidad VIDA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald800)),
            const SizedBox(height: 4),
            Text('Comparte y conecta con otros creyentes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.emerald500)),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.emerald600,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.emerald600,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Iniciar sesión'),
                  Tab(text: 'Registrarse'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isRegister) ...[
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDec('Nombre'),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailLocalCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _fieldDec('Correo'),
                    onChanged: (v) {
                      if (!v.contains('@')) return;
                      final parts = v.split('@');
                      final local = parts.first;
                      final typedDomain =
                          parts.length > 1 ? '@${parts[1].toLowerCase()}' : '';
                      _emailLocalCtrl.value = TextEditingValue(
                        text: local,
                        selection:
                            TextSelection.collapsed(offset: local.length),
                      );
                      for (final d in _domains) {
                        if (d.toLowerCase() == typedDomain) {
                          setState(() => _domain = d);
                          break;
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 148,
                  child: InputDecorator(
                    decoration: _fieldDec('').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _domain,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald800,
                        ),
                        items: [
                          for (final d in _domains)
                            DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _domain = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: _fieldDec('Contraseña').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        isRegister ? 'Registrarse' : 'Iniciar sesión',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.emerald200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.emerald200),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

String _resolveAuthorName(User user, BuildContext context) {
  final display = user.displayName?.trim() ?? '';
  if (display.isNotEmpty) return display;
  final splash = VidaApp.of(context).userName.trim();
  if (splash.isNotEmpty) return splash;
  final email = user.email ?? '';
  if (email.contains('@')) return email.split('@').first;
  return 'Usuario';
}

String _resolveAuthorEmail(User user) => user.email?.trim() ?? '';

String _handleLocal(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  var local = v.contains('@') ? v.split('@').first : v;
  local = local.replaceFirst(RegExp(r'^@+'), '');
  if (local.isEmpty) return '';
  return '@$local';
}

/// Handle legible; vacío si no aporta nada distinto del nombre visible.
String _displayHandle(String? email, String? fallbackName) {
  final e = email?.trim() ?? '';
  String handle = '';
  if (e.isNotEmpty) {
    handle = _handleLocal(e);
  } else {
    final n = fallbackName?.trim() ?? '';
    if (n.contains('@')) handle = _handleLocal(n);
  }
  if (handle.isEmpty) return '';
  final bare = handle.substring(1).toLowerCase();
  final name = (fallbackName ?? '').trim().toLowerCase();
  if (name.isNotEmpty && (name == bare || name == handle.toLowerCase())) {
    return '';
  }
  return handle;
}

String _formatCommunityDate(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return '${d.day}/${d.month}/${d.year}';
}

// ─────────────── Feed View ───────────────

class _FeedView extends StatefulWidget {
  final String? focusPostId;

  const _FeedView({this.focusPostId});

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  final _postCtrl = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _posting = false;
  Set<String> _hidden = {};
  bool _focusChecked = false;

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    final ids = await ReportService.hiddenIds();
    if (mounted) setState(() => _hidden = ids);
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _postCtrl.text.trim();
    if (content.isEmpty || _posting) return;
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    setState(() => _posting = true);
    try {
      await _db.collection('community_posts').add({
        'userId': user.uid,
        'authorName': _resolveAuthorName(user, context),
        'authorEmail': _resolveAuthorEmail(user),
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'likedBy': [],
      });
      if (mounted) _postCtrl.clear();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Material(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              controller: _postCtrl,
              maxLines: 3,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _createPost(),
              decoration: InputDecoration(
                hintText: 'Comparte algo con la comunidad…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 48, 12),
                counterStyle: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                suffixIcon: IconButton(
                  onPressed: _posting ? null : _createPost,
                  icon: Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: _posting
                        ? cs.onSurface.withValues(alpha: 0.3)
                        : AppColors.emerald600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('community_posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Error al cargar',
                      style: TextStyle(color: AppColors.emerald500)),
                );
              }
              if (!snap.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                      color: AppColors.emerald600),
                );
              }
              final posts = snap.data!.docs.where((d) {
                final key = ReportService.keyFor('post', d.id);
                return !_hidden.contains(key);
              }).toList();
              final focusId = widget.focusPostId?.trim();
              if (!_focusChecked &&
                  focusId != null &&
                  focusId.isNotEmpty &&
                  posts.isNotEmpty) {
                _focusChecked = true;
                final found = posts.any((d) => d.id == focusId);
                if (!found) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se encontró esa publicación (puede haberse borrado).',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                }
              }
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_rounded,
                          size: 56, color: AppColors.emerald300),
                      const SizedBox(height: 12),
                      Text('Sé el primero en publicar',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.emerald500)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: posts.length,
                itemBuilder: (context, i) => _PostCard(
                  key: ValueKey(posts[i].id),
                  postDoc: posts[i],
                  expandComments: focusId != null && posts[i].id == focusId,
                  onHidden: () => _loadHidden(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────── Post Card ───────────────

class _PostCard extends StatefulWidget {
  final QueryDocumentSnapshot postDoc;
  final VoidCallback? onHidden;
  final bool expandComments;

  const _PostCard({
    super.key,
    required this.postDoc,
    this.onHidden,
    this.expandComments = false,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _showComments = widget.expandComments;
  bool _liking = false;
  bool _commenting = false;
  final _commentCtrl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _data =>
      widget.postDoc.data() as Map<String, dynamic>;

  bool get _isLiked {
    final raw = _data['likedBy'];
    final likedBy = raw is List ? raw.map((e) => '$e').toList() : const <String>[];
    final uid = _auth.currentUser?.uid;
    return uid != null && likedBy.contains(uid);
  }

  bool get _isAuthor {
    final uid = _auth.currentUser?.uid;
    final authorId = _data['userId'] as String?;
    return uid != null && authorId != null && uid == authorId;
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text(
          'Se borrará esta publicación y sus comentarios. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final ref = _db.collection('community_posts').doc(widget.postDoc.id);
      final comments = await ref.collection('comments').limit(200).get();
      final batch = _db.batch();
      for (final d in comments.docs) {
        batch.delete(d.reference);
      }
      batch.delete(ref);
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación eliminada')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar. Revisa tu conexión o permisos.'),
        ),
      );
    }
  }

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null || _liking) return;
    final fromName = _resolveAuthorName(user!, context);
    setState(() => _liking = true);
    final ref = _db.collection('community_posts').doc(widget.postDoc.id);
    var addedLike = false;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};
        final likedBy = (data['likedBy'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList();
        final liked = likedBy.contains(uid);
        if (liked) {
          likedBy.remove(uid);
          addedLike = false;
        } else {
          likedBy.add(uid);
          addedLike = true;
        }
        tx.update(ref, {
          'likedBy': likedBy,
          'likeCount': likedBy.length,
        });
      });
      if (addedLike) {
        final authorId = (_data['userId'] as String?) ?? '';
        await CommunityPushService.notifyAuthor(
          toUid: authorId,
          type: 'like',
          postId: widget.postDoc.id,
          fromName: fromName,
        );
      }
    } catch (_) {
      // Stream refresca el estado real; ignoramos fallos de red.
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _commenting) return;
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final fromName = _resolveAuthorName(user, context);

    setState(() => _commenting = true);
    try {
      await _db
          .collection('community_posts')
          .doc(widget.postDoc.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'authorName': fromName,
        'authorEmail': _resolveAuthorEmail(user),
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _commentCtrl.clear();
      final authorId = (_data['userId'] as String?) ?? '';
      await CommunityPushService.notifyAuthor(
        toUid: authorId,
        type: 'comment',
        postId: widget.postDoc.id,
        fromName: fromName,
      );
    } finally {
      if (mounted) setState(() => _commenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final likedRaw = _data['likedBy'];
    final likedBy = likedRaw is List
        ? likedRaw.map((e) => '$e').toList()
        : const <String>[];
    final likeCount = likedBy.isNotEmpty
        ? likedBy.length
        : (_data['likeCount'] is num
            ? (_data['likeCount'] as num).toInt()
            : 0);
    final authorName = (_data['authorName'] as String?)?.trim() ?? '';
    final handle = _displayHandle(
      _data['authorEmail'] as String?,
      authorName,
    );
    final cs = Theme.of(context).colorScheme;
    final dateLabel =
        _formatCommunityDate(_data['createdAt'] as Timestamp?);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: authorName.isNotEmpty ? authorName : 'Usuario',
                  radius: 18,
                  backgroundColor: AppColors.emerald200,
                  foregroundColor: AppColors.emerald700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName.isNotEmpty ? authorName : 'Usuario',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (handle.isNotEmpty) handle,
                          if (dateLabel.isNotEmpty) dateLabel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded,
                      size: 22, color: cs.onSurface.withValues(alpha: 0.45)),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await _deletePost();
                      return;
                    }
                    if (v != 'report') return;
                    await ReportService.submit(
                      targetType: 'post',
                      targetId: widget.postDoc.id,
                    );
                    if (!mounted) return;
                    widget.onHidden?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Gracias. Ocultamos esta publicación aquí.'),
                      ),
                    );
                  },
                  itemBuilder: (_) => [
                    if (_isAuthor)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Reportar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _data['content'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: _liking ? null : _toggleLike,
                  icon: Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: _isLiked
                        ? Colors.redAccent
                        : AppColors.emerald500,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '$likeCount',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.emerald600),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showComments = !_showComments),
                  icon: Icon(
                    _showComments
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppColors.emerald500,
                  ),
                  label: Text(
                    _showComments ? 'Ocultar' : 'Responder',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.emerald600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            if (_showComments) ...[
              Divider(height: 16, color: cs.outlineVariant.withValues(alpha: 0.4)),
              _CommentsList(postId: widget.postDoc.id),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      maxLines: 2,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe una respuesta…',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        counterStyle: TextStyle(
                          fontSize: 9,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _commenting ? null : _addComment,
                    icon: Icon(Icons.send_rounded, size: 18, color: cs.onPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      disabledBackgroundColor:
                          AppColors.emerald600.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────── Comments List ───────────────

class _CommentsList extends StatelessWidget {
  final String postId;
  const _CommentsList({required this.postId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final comments = snap.data!.docs;
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin respuestas aún',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4),
          itemCount: comments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = comments[i];
            final c = doc.data() as Map<String, dynamic>;
            final name = (c['authorName'] as String?)?.trim() ?? '';
            final handle = _displayHandle(
              c['authorEmail'] as String?,
              name,
            );
            final dateLabel =
                _formatCommunityDate(c['createdAt'] as Timestamp?);
            final meta = [
              if (handle.isNotEmpty) handle,
              if (dateLabel.isNotEmpty) dateLabel,
            ].join(' · ');
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: name.isNotEmpty ? name : 'Usuario',
                  radius: 12,
                  backgroundColor: AppColors.emerald100,
                  foregroundColor: AppColors.emerald700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Usuario',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              await ReportService.submit(
                                targetType: 'comment',
                                targetId: doc.id,
                                parentId: postId,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comentario reportado'),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        c['content'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: cs.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
