import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Siembra iglesias protestantes/evangélicas de México (OpenStreetMap)
/// en la colección Firestore `iglesias`, una sola vez por dispositivo/flag.
class IglesiaSeedService {
  static const prefsKey = 'iglesias_mexico_seed_v1';
  static const assetPath = 'assets/data/iglesias_mexico.json';

  /// Idempotente: doc id = osm_id; merge no duplica.
  static Future<int> ensureSeeded({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(prefsKey) ?? false)) return 0;

    late final List<dynamic> list;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.setBool(prefsKey, true);
        return 0;
      }
      list = decoded;
    } catch (_) {
      return 0;
    }

    final col = FirebaseFirestore.instance.collection('iglesias');
    var written = 0;
    final pending = <({String id, Map<String, dynamic> data})>[];

    for (final e in list) {
      if (e is! Map) continue;
      final osmId = '${e['osm_id'] ?? ''}'.trim();
      final nombre = '${e['nombre'] ?? ''}'.trim();
      final lat = e['latitud'];
      final lng = e['longitud'];
      if (nombre.isEmpty || lat is! num || lng is! num) continue;

      final id = osmId.isNotEmpty
          ? osmId.replaceAll('/', '_')
          : 'seed_${nombre.hashCode}_${lat}_${lng}';

      pending.add((
        id: id,
        data: {
          'nombre': nombre,
          'ciudad': '${e['ciudad'] ?? 'México'}'.trim(),
          'descripcion':
              '${e['descripcion'] ?? 'Iglesia cristiana protestante / evangélica'}',
          'latitud': lat.toDouble(),
          'longitud': lng.toDouble(),
          'miembros': 0,
          'asistentes': <String>[],
          'creado_por': 'seed_vida_0.9',
          'osm_id': osmId,
          'seed': true,
        },
      ));
    }

    for (var i = 0; i < pending.length; i += 400) {
      final chunk = pending.skip(i).take(400);
      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        batch.set(col.doc(item.id), item.data, SetOptions(merge: true));
        written++;
      }
      await batch.commit();
    }

    await prefs.setBool(prefsKey, true);
    return written;
  }
}
