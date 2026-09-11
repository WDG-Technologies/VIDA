import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/iglesia_seed.dart';
import '../services/feature_tips.dart';
import '../theme/app_theme.dart';
import 'community_screen.dart';

/// Raster tiles sin API key (Carto ahora exige clave y muestra watermark).
TileLayer vidaMapTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.vida.project',
      maxZoom: 19,
    );

/// Atribución OSM sin el prefijo «flutter_map |».
Widget vidaMapAttribution() => Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );

class MapaIglesiasScreen extends StatefulWidget {
  const MapaIglesiasScreen({super.key});

  @override
  State<MapaIglesiasScreen> createState() => _MapaIglesiasScreenState();
}

class _MapaIglesiasScreenState extends State<MapaIglesiasScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _churches = [];
  List<Map<String, dynamic>> _filtered = [];
  LatLng? _myLocation;
  bool _loading = true;
  bool _searched = false;
  Timer? _searchTimer;
  StreamSubscription<Position>? _positionSub;

  static const _defaultCenter = LatLng(19.4326, -99.1332);

  @override
  void initState() {
    super.initState();
    _loadIglesias();
    _searchCtrl.addListener(_onSearch);
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FeatureTips.mapa(context);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final granted = await Geolocator.requestPermission();
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        return;
      }
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_myLocation!, 13);
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  Future<void> _loadIglesias() async {
    try {
      await IglesiaSeedService.ensureSeeded();
      final snap = await _db.collection('iglesias').get();
      if (!mounted) return;
      _churches = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      _filtered = List.from(_churches);
    } catch (_) {
      if (!mounted) return;
      _churches = [];
      _filtered = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim();
    _searchTimer?.cancel();
    if (q.length >= 3) {
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _doSearch();
      });
    } else if (mounted) {
      setState(() => _searched = false);
    }
  }

  void _doSearch() {
    if (!mounted) return;
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _searched = true;
      if (q.isEmpty) {
        _filtered = List.from(_churches);
      } else {
        _filtered = _churches.where((c) {
          final nombre = '${c['nombre'] ?? ''}'.toLowerCase();
          final ciudad = '${c['ciudad'] ?? ''}'.toLowerCase();
          return nombre.contains(q) || ciudad.contains(q);
        }).toList();
      }
    });
  }

  void _showChurchSheet(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ChurchDetailSheet(
        docId: docId,
        onJoined: () {
          Navigator.pop(ctx);
          _loadIglesias();
        },
      ),
    );
  }

  /// Devuelve null si faltan o son inválidas lat/lng (evita tumbar el mapa).
  static LatLng? _coordsOf(Map<String, dynamic> c) {
    final latRaw = c['latitud'];
    final lngRaw = c['longitud'];
    final lat = latRaw is num
        ? latRaw.toDouble()
        : double.tryParse('$latRaw');
    final lng = lngRaw is num
        ? lngRaw.toDouble()
        : double.tryParse('$lngRaw');
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  Future<void> _addChurch({
    required String nombre,
    required String ciudad,
    required String descripcion,
    required double latitud,
    required double longitud,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    // Anyone can add a church; only real accounts count as attending.
    final loggedIn = user != null && !user.isAnonymous;
    final uid = user?.uid;
    await _db.collection('iglesias').add({
      'nombre': nombre,
      'ciudad': ciudad,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'miembros': loggedIn ? 1 : 0,
      'asistentes': loggedIn && uid != null ? [uid] : <String>[],
      'creado_por': uid ?? '',
    });
    await _loadIglesias();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddChurchSheet(onSubmit: _addChurch),
    );
  }

  void _goToMyLocation() {
    if (_myLocation != null) {
      _mapController.move(_myLocation!, 15);
    }
  }

  Widget _mapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _myLocation ?? _defaultCenter,
            initialZoom: _myLocation != null ? 13 : 5,
            onTap: (tapPos, latlng) {
              Map<String, dynamic>? nearest;
              var bestDist = 0.002; // ~200 m
              for (final c in _filtered) {
                final point = _coordsOf(c);
                if (point == null) continue;
                final dist = (latlng.latitude - point.latitude).abs() +
                    (latlng.longitude - point.longitude).abs();
                if (dist < bestDist) {
                  bestDist = dist;
                  nearest = c;
                }
              }
              if (nearest != null) {
                _showChurchSheet(nearest, nearest['_id'] as String);
              }
            },
          ),
          children: [
            vidaMapTileLayer(),
            MarkerLayer(
              markers: [
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ..._filtered.map((c) {
                  final point = _coordsOf(c);
                  if (point == null) return null;
                  return Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () =>
                          _showChurchSheet(c, c['_id'] as String),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.emerald600,
                        size: 36,
                      ),
                    ),
                  );
                }).whereType<Marker>(),
              ],
            ),
            vidaMapAttribution(),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'locate',
                                foregroundColor: AppColors.emerald700,
                onPressed: _goToMyLocation,
                child: Icon(Icons.my_location_rounded, size: 22),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'add_church',
                backgroundColor: AppColors.emerald600,
                foregroundColor: Colors.white,
                onPressed: _openAddSheet,
                child: Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        if (!_loading && _churches.isEmpty)
          Positioned(
            left: 16,
            right: 72,
            bottom: 24,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Text(
                  'Aún no hay iglesias en el mapa. Toca + para agregar la tuya.',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.emerald700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchResultsView() {
    if (_filtered.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 12, endIndent: 12),
        itemBuilder: (context, i) {
          final c = _filtered[i];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Icon(Icons.location_on_rounded,
                color: AppColors.emerald600, size: 28),
            title: Text(c['nombre'] ?? '',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.emerald900)),
            subtitle: Text(c['ciudad'] ?? '',
                style:
                    TextStyle(fontSize: 13, color: AppColors.emerald600)),
            trailing: Icon(Icons.chevron_right_rounded,
                color: AppColors.emerald400),
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searched = false);
              final point = _coordsOf(c);
              if (point != null) {
                _mapController.move(point, 15);
              }
              _showChurchSheet(c, c['_id'] as String);
            },
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: AppColors.emerald300),
            const SizedBox(height: 16),
            Text(
              'No encontramos esa congregación',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald800),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openAddSheet,
              icon: Icon(Icons.add_location_rounded, size: 20),
              label: Text('Agregar congregación',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald700,
                side: BorderSide(color: AppColors.emerald600),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Iglesias cerca',
            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o ciudad',
                  hintStyle: TextStyle(fontSize: 14),
                  prefixIcon: IconButton(
                    icon: Icon(Icons.search_rounded, size: 22),
                    onPressed: _doSearch,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searched = false);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.emerald50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchCtrl.text.isNotEmpty && _searched
                      ? _searchResultsView()
                      : _searchCtrl.text.isNotEmpty
                          ? SizedBox.expand(
                              child: ColoredBox(
                                  color: Theme.of(context).colorScheme.surface))
                          : _mapView(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet: detalle de iglesia ─────────────────────────

class _ChurchDetailSheet extends StatefulWidget {
  final String docId;
  final VoidCallback onJoined;

  const _ChurchDetailSheet({
    required this.docId,
    required this.onJoined,
  });

  @override
  State<_ChurchDetailSheet> createState() => _ChurchDetailSheetState();
}

class _ChurchDetailSheetState extends State<_ChurchDetailSheet> {
  bool _joining = false;

  Future<void> _promptLogin() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cuenta necesaria'),
        content: const Text(
          'Para marcar que asistes a esta iglesia necesitas una cuenta. '
          'El resto del mapa se puede usar sin registrarte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald600,
            ),
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      // Mantener el sheet abierto debajo; al volver, unir si ya hay cuenta.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CommunityScreen()),
      );
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await _joinChurch(user.uid);
      }
    }
  }

  Future<void> _joinChurch(String uid) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final ref =
          FirebaseFirestore.instance.collection('iglesias').doc(widget.docId);
      final joined = await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final asistentes = (snap.data()?['asistentes'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList();
        if (asistentes.contains(uid)) return false;
        tx.update(ref, {
          'miembros': FieldValue.increment(1),
          'asistentes': FieldValue.arrayUnion([uid]),
        });
        return true;
      });
      if (joined && mounted) widget.onJoined();
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final needsLogin = user == null || user.isAnonymous;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.emerald300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('iglesias')
                  .doc(widget.docId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = snap.data!.data() as Map<String, dynamic>;
                final asistentes = (data['asistentes'] as List<dynamic>? ?? [])
                    .map((e) => '$e')
                    .toList();
                final yaAsiste =
                    !needsLogin &&
                    uid != null &&
                    asistentes.contains(uid);

                VoidCallback? onAttend;
                if (yaAsiste || _joining) {
                  onAttend = null;
                } else if (needsLogin) {
                  onAttend = _promptLogin;
                } else {
                  onAttend = () => _joinChurch(uid!);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['nombre'] ?? '',
                        style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald900)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: AppColors.emerald500),
                        const SizedBox(width: 4),
                        Text(data['ciudad'] ?? '',
                            style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 13,
                                color: AppColors.emerald600)),
                        const Spacer(),
                        Icon(Icons.people_rounded,
                            size: 16, color: AppColors.emerald500),
                        const SizedBox(width: 4),
                        Text('${asistentes.length}',
                            style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald800)),
                      ],
                    ),
                    if ((data['descripcion']?.toString().trim() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(data['descripcion'].toString(),
                          style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.emerald700)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAttend,
                        icon: Icon(
                            yaAsiste
                                ? Icons.check_rounded
                                : Icons.volunteer_activism_rounded,
                            size: 20),
                        label: Text(
                            yaAsiste
                                ? 'Ya asistes aquí'
                                : 'Yo asisto aquí',
                            style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: yaAsiste
                              ? AppColors.emerald200
                              : AppColors.emerald600,
                          foregroundColor: yaAsiste
                              ? AppColors.emerald600
                              : Colors.white,
                          disabledBackgroundColor: AppColors.emerald200,
                          disabledForegroundColor: AppColors.emerald600,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (needsLogin) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Solo se pide cuenta para marcar asistencia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 11,
                            color: AppColors.emerald400),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final lat = data['latitud'];
                          final lng = data['longitud'];
                          if (lat != null && lng != null) {
                            launchUrl(Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                            ));
                          }
                        },
                        icon: Icon(Icons.directions_rounded,
                            size: 20),
                        label: Text('Cómo llegar',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emerald700,
                          side: BorderSide(color: AppColors.emerald600),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet: agregar iglesia ──────────────────────────

class _AddChurchSheet extends StatefulWidget {
  final Future<void> Function({
    required String nombre,
    required String ciudad,
    required String descripcion,
    required double latitud,
    required double longitud,
  }) onSubmit;

  const _AddChurchSheet({required this.onSubmit});

  @override
  State<_AddChurchSheet> createState() => _AddChurchSheetState();
}

class _AddChurchSheetState extends State<_AddChurchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _descripCtrl = TextEditingController();
  final _searchAddrCtrl = TextEditingController();
  final MapController _miniMapController = MapController();

  LatLng? _selectedLocation;
  LatLng? _myLocation;
  bool _submitting = false;
  bool _searchingLocation = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _initMiniMapLocation();
  }

  Future<void> _searchLocation(String query) async {
    if (!mounted || query.trim().isEmpty) return;

    final coordPattern = RegExp(
        r'^\s*([+-]?\d+\.?\d*)\s*[, ]\s*([+-]?\d+\.?\d*)\s*$');
    final match = coordPattern.firstMatch(query.trim());
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null &&
          lat >= -90 && lat <= 90 &&
          lng >= -180 && lng <= 180) {
        final loc = LatLng(lat, lng);
        setState(() => _selectedLocation = loc);
        _miniMapController.move(loc, 15);
        return;
      }
    }

    setState(() => _searchingLocation = true);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      var urlStr = 'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=mx';
      if (_myLocation != null) {
        final lat = _myLocation!.latitude;
        final lng = _myLocation!.longitude;
        const kmPerDeg = 111.0;
        final degRadius = 30.0 / kmPerDeg;
        final dlng = 30.0 / (kmPerDeg * _kmPerLng(lat));
        final minLat = (lat - degRadius).toStringAsFixed(4);
        final maxLat = (lat + degRadius).toStringAsFixed(4);
        final minLng = (lng - dlng).toStringAsFixed(4);
        final maxLng = (lng + dlng).toStringAsFixed(4);
        urlStr += '&viewbox=$minLng,$minLat,$maxLng,$maxLat&bounded=1';
      }
      final url = Uri.parse(urlStr);
      final request = await client.getUrl(url);
      request.headers.set(
        'User-Agent',
        'VIDA/0.9.0 (com.vida.project; https://github.com/WDG-Technologies/VIDA)',
      );
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(body);
      if (!mounted) return;
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded[0];
        if (first is Map) {
          final lat = double.tryParse('${first['lat']}');
          final lng = double.tryParse('${first['lon']}');
          if (lat != null &&
              lng != null &&
              lat >= -90 &&
              lat <= 90 &&
              lng >= -180 &&
              lng <= 180) {
            final loc = LatLng(lat, lng);
            setState(() => _selectedLocation = loc);
            _miniMapController.move(loc, 15);
          }
        }
      }
    } catch (_) {
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  Future<void> _initMiniMapLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final granted = await Geolocator.requestPermission();
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        return;
      }
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = loc);
      _miniMapController.move(loc, 13);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ciudadCtrl.dispose();
    _descripCtrl.dispose();
    _searchAddrCtrl.dispose();
    _searchTimer?.cancel();
    _miniMapController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Selecciona una ubicación en el mapa',
                style: TextStyle(fontFamily: 'DM Sans'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        nombre: _nombreCtrl.text.trim(),
        ciudad: _ciudadCtrl.text.trim(),
        descripcion: _descripCtrl.text.trim(),
        latitud: _selectedLocation!.latitude,
        longitud: _selectedLocation!.longitude,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la iglesia'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.emerald300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Agregar congregación',
                style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald900)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchAddrCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar dirección o coordenadas',
                hintStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchAddrCtrl.text.isNotEmpty
                        ? IconButton(
                            icon:
                                Icon(Icons.clear_rounded, size: 18),
                            onPressed: _searchAddrCtrl.clear,
                          )
                        : null),
                filled: true,
                fillColor: AppColors.emerald50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                _searchTimer?.cancel();
                if (v.trim().length >= 3) {
                  _searchTimer =
                      Timer(const Duration(milliseconds: 400), () {
                    if (!mounted) return;
                    _searchLocation(v);
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _miniMapController,
                      options: MapOptions(
                        initialCenter: _myLocation ??
                            const LatLng(19.4326, -99.1332),
                        initialZoom: _myLocation != null ? 13 : 5,
                        onTap: (_, latlng) {
                          setState(
                              () => _selectedLocation = latlng);
                        },
                      ),
                      children: [
                        vidaMapTileLayer(),
                        MarkerLayer(
                          markers: [
                            if (_myLocation != null)
                              Marker(
                                point: _myLocation!,
                                width: 26,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue
                                        .withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration:
                                          BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_selectedLocation != null)
                              Marker(
                                point: _selectedLocation!,
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.emerald600,
                                  size: 36,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: FloatingActionButton.small(
                        heroTag: 'mini_locate',
                                                foregroundColor: AppColors.emerald700,
                        onPressed: () {
                          if (_myLocation != null) {
                            _miniMapController
                                .move(_myLocation!, 13);
                          }
                        },
                        child: Icon(
                            Icons.my_location_rounded,
                            size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ubicación: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      color: AppColors.emerald500),
                ),
              ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: _inputDec('Nombre de la iglesia'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa el nombre'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ciudadCtrl,
                    decoration: _inputDec('Ciudad'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa la ciudad'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descripCtrl,
                    decoration: _inputDec('Descripción (opcional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Guardar congregación',
                        style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _kmPerLng(double lat) {
    return 111.32 * math.cos(lat * math.pi / 180.0);
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: 'DM Sans', fontSize: 13),
      filled: true,
      fillColor: AppColors.emerald50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
