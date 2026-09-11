import 'dart:convert';

import 'package:flutter/services.dart';

import 'fav.dart';

/// Versículo del día desde `assets/data/daily_verses.json` (~149 citas).
class DailyVerseService {
  DailyVerseService._();

  static List<FavVerse>? _cache;

  static Future<List<FavVerse>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final raw =
          await rootBundle.loadString('assets/data/daily_verses.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) {
        _cache = const [fallback];
        return _cache!;
      }
      final list = <FavVerse>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final ref = '${e['referencia'] ?? e['reference'] ?? ''}'.trim();
        final text = '${e['versiculo'] ?? e['texto'] ?? e['text'] ?? ''}'.trim();
        if (ref.isEmpty || text.isEmpty) continue;
        list.add(FavVerse(referencia: ref, versiculo: text));
      }
      _cache = list.isEmpty ? const [fallback] : List.unmodifiable(list);
    } catch (_) {
      _cache = const [fallback];
    }
    return _cache!;
  }

  /// Índice estable por día civil (misma lógica que el mazo del inicio).
  static int dayIndex([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day)
        .difference(DateTime(2024, 1, 1))
        .inDays
        .abs();
  }

  static Future<FavVerse> forToday([DateTime? now]) async {
    final all = await loadAll();
    return all[dayIndex(now) % all.length];
  }

  /// Sync helper for widgets that already have the list loaded.
  static FavVerse pickFrom(List<FavVerse> all, [DateTime? now]) {
    if (all.isEmpty) return fallback;
    return all[dayIndex(now) % all.length];
  }

  /// Solo si falla la carga del asset.
  static const fallback = FavVerse(
    referencia: 'Hebreos 11:1',
    versiculo:
        'Es, pues, la fe la sustancia de las cosas que se esperan, '
        'la demostración de las cosas que no se ven.',
  );
}
