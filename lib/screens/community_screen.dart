import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/feature_tips.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

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
        title: Text('Comunidad',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (!isAnonymous)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                try {
                  await _auth.signOut();
                  await _auth.signInAnonymously();
                } catch (_) {}
                if (mounted) setState(() {});
              },
              icon: Icon(Icons.logout_rounded,
                  color: AppColors.emerald700, size: 22),
            ),
        ],
      ),
      body: isAnonymous
          ? _AuthView(onAuthed: _refreshAuth)
          : _FeedView(),
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
  final local = v.contains('@') ? v.split('@').first : v;
  // Avoid "@@user" if stored value already starts with @.
  return local.startsWith('@') ? local : '@$local';
}

String _displayHandle(String? email, String? fallbackName) {
  final e = email?.trim() ?? '';
  if (e.isNotEmpty) return _handleLocal(e);
  final n = fallbackName?.trim() ?? '';
  if (n.isNotEmpty && n.contains('@')) return _handleLocal(n);
  return '';
}

// ─────────────── Feed View ───────────────

class _FeedView extends StatefulWidget {
  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  final _postCtrl = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _posting = false;
  Set<String> _hidden = {};

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  fontSize: 13, color: AppColors.emerald300),
              filled: true,
              fillColor: AppColors.emerald50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.fromLTRB(16, 12, 48, 12),
              counterStyle: TextStyle(
                  fontSize: 10, color: AppColors.emerald300),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IconButton(
                  onPressed: _posting ? null : _createPost,
                  icon: Icon(Icons.send_rounded, size: 20, color: AppColors.emerald600),
                ),
              ),
          ),
        ),
        ),
        const SizedBox(height: 8),
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
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_rounded,
                          size: 56, color: AppColors.emerald300),
                      SizedBox(height: 12),
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
  const _PostCard({super.key, required this.postDoc, this.onHidden});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showComments = false;
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

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _toggleLike() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _liking) return;
    setState(() => _liking = true);
    final ref = _db.collection('community_posts').doc(widget.postDoc.id);
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
        } else {
          likedBy.add(uid);
        }
        tx.update(ref, {
          'likedBy': likedBy,
          'likeCount': likedBy.length,
        });
      });
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

    setState(() => _commenting = true);
    try {
      await _db
          .collection('community_posts')
          .doc(widget.postDoc.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'authorName': _resolveAuthorName(user, context),
        'authorEmail': _resolveAuthorEmail(user),
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _commentCtrl.clear();
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
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
                UserAvatar(
                  name: authorName.isNotEmpty ? authorName : 'Usuario',
                  radius: 14,
                  backgroundColor: AppColors.emerald200,
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
                              authorName.isNotEmpty
                                  ? authorName
                                  : 'Usuario',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emerald800),
                            ),
                          ),
                          Text(
                            _formatDate(
                                _data['createdAt'] as Timestamp?),
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.emerald400),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                size: 18, color: AppColors.emerald400),
                            onSelected: (v) async {
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
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'report',
                                child: Text('Reportar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (handle.isNotEmpty)
                        Text(
                          handle,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.emerald400),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_data['content'] ?? '',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.emerald900)),
            const SizedBox(height: 10),
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
                Text('$likeCount',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.emerald600)),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () =>
                      setState(() => _showComments = !_showComments),
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: AppColors.emerald500,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_showComments) ...[
              const Divider(height: 1),
              _CommentsList(postId: widget.postDoc.id),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      maxLines: 2,
                      maxLength: 500,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe un comentario…',
                        hintStyle: TextStyle(
                            fontSize: 12, color: AppColors.emerald300),
                        filled: true,
                        fillColor: AppColors.emerald50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        counterStyle: TextStyle(
                            fontSize: 9, color: AppColors.emerald300),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _commenting ? null : _addComment,
                    icon: Icon(Icons.send_rounded,
                        size: 18, color: AppColors.emerald600),
                    visualDensity: VisualDensity.compact,
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
            child: Text('Sin comentarios',
                style:
                    TextStyle(fontSize: 12, color: AppColors.emerald400)),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          itemCount: comments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final doc = comments[i];
            final c = doc.data() as Map<String, dynamic>;
            final name = (c['authorName'] as String?)?.trim() ?? '';
            final handle = _displayHandle(
              c['authorEmail'] as String?,
              name,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isNotEmpty ? name : 'Usuario',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald700),
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
                      child: Icon(Icons.flag_outlined,
                          size: 14, color: AppColors.emerald300),
                    ),
                  ],
                ),
                if (handle.isNotEmpty)
                  Text(
                    handle,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.emerald400),
                  ),
                const SizedBox(height: 2),
                Text(c['content'] ?? '',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.emerald800)),
              ],
            );
          },
        );
      },
    );
  }
}
