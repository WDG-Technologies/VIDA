import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bible_highlights.dart';
import 'bible_study.dart';
import 'streak.dart';
import 'vida_verse_bank.dart';

/// Local behavioral signals for the VIDA algorithm (no account required).
class VidaSignals {
  static const _kCategories = 'vida_signal_categories';
  static const _kBooks = 'vida_signal_books';
  static const _kEvents = 'vida_signal_events';
  static const _kLastChapter = 'vida_signal_last_chapter';

  /// Soft-weight map of tag → score from recent activity.
  static Future<Map<String, double>> collect() async {
    final prefs = await SharedPreferences.getInstance();
    final weights = <String, double>{};

    void bump(String tag, [double w = 1]) {
      weights[tag] = (weights[tag] ?? 0) + w;
    }

    // Situation categories opened recently.
    final cats = prefs.getStringList(_kCategories) ?? const [];
    for (final c in cats) {
      for (final tag in _mapCategory(c)) {
        bump(tag, 1.4);
      }
    }

    // Bible books visited.
    final books = prefs.getStringList(_kBooks) ?? const [];
    for (final b in books) {
      for (final tag in _mapBook(b)) {
        bump(tag, 0.6);
      }
    }

    // Generic event counters: evangelizate, arcade, etc.
    final events = _decodeEvents(prefs.getString(_kEvents));
    for (final e in events.entries) {
      final n = (e.value as num?)?.toDouble() ?? 0;
      for (final tag in _mapEvent(e.key)) {
        bump(tag, 0.35 * n.clamp(0, 8));
      }
    }

    // Highlights count → hunger for Word / comfort.
    final highlights = await BibleHighlights.loadKeys();
    if (highlights.isNotEmpty) {
      bump(VidaTags.fe, 0.8);
      bump(VidaTags.esperanza, 0.5);
      if (highlights.length >= 5) bump(VidaTags.proposito, 0.6);
    }

    // Studies.
    final studies = await BibleStudyService.getAll();
    if (studies.isNotEmpty) {
      bump(VidaTags.sabiduria, 1.0);
      bump(VidaTags.fe, 0.5);
      for (final s in studies.take(8)) {
        for (final tag in _mapBook(s.book)) {
          bump(tag, 0.4);
        }
      }
    }

    // Streak.
    final streak = await StreakService.getCount();
    if (streak >= 3) bump(VidaTags.fortaleza, 0.8);
    if (streak >= 7) bump(VidaTags.paciencia, 0.7);
    if (streak == 0) bump(VidaTags.esperanza, 0.5);

    // Time of day.
    final h = DateTime.now().hour;
    if (h < 6 || h >= 22) {
      bump(VidaTags.paz, 0.7);
      bump(VidaTags.ansiedad, 0.4);
    } else if (h < 12) {
      bump(VidaTags.proposito, 0.5);
      bump(VidaTags.gozo, 0.3);
    } else if (h >= 18) {
      bump(VidaTags.descanso, 0.5);
      bump(VidaTags.gratitud, 0.4);
    }

    // Weekday: Monday push / weekend rest.
    final wd = DateTime.now().weekday;
    if (wd == DateTime.monday) bump(VidaTags.fortaleza, 0.4);
    if (wd == DateTime.sunday) bump(VidaTags.oracion, 0.5);

    if (weights.isEmpty) {
      bump(VidaTags.esperanza, 1);
      bump(VidaTags.fe, 1);
      bump(VidaTags.paz, 0.8);
    }
    return weights;
  }

  static Future<void> trackCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCategories) ?? <String>[];
    list.remove(category);
    list.insert(0, category);
    while (list.length > 12) {
      list.removeLast();
    }
    await prefs.setStringList(_kCategories, list);
  }

  static Future<void> trackBibleBook(String bookName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kBooks) ?? <String>[];
    list.remove(bookName);
    list.insert(0, bookName);
    while (list.length > 16) {
      list.removeLast();
    }
    await prefs.setStringList(_kBooks, list);
  }

  static Future<void> trackChapter(int bookIndex, int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastChapter, '$bookIndex:$chapter');
  }

  static Map<String, dynamic> _decodeEvents(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '{}');
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  static Future<void> trackEvent(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeEvents(prefs.getString(_kEvents));
    map[name] = ((map[name] as num?)?.toInt() ?? 0) + 1;
    await prefs.setString(_kEvents, jsonEncode(map));
  }

  static List<String> _mapCategory(String c) {
    final k = c.toLowerCase();
    if (k.contains('miedo') || k.contains('temor')) {
      return [VidaTags.miedo, VidaTags.confianza];
    }
    if (k.contains('ansied') || k.contains('estres') || k.contains('preocup')) {
      return [VidaTags.ansiedad, VidaTags.paz];
    }
    if (k.contains('triste') || k.contains('duelo') || k.contains('dolor')) {
      return [VidaTags.tristeza, VidaTags.esperanza];
    }
    if (k.contains('soled')) return [VidaTags.soledad, VidaTags.amor];
    if (k.contains('perdon')) return [VidaTags.perdon];
    if (k.contains('tentac') || k.contains('pecado')) {
      return [VidaTags.tentacion, VidaTags.fortaleza];
    }
    if (k.contains('propos') || k.contains('llamado')) {
      return [VidaTags.proposito];
    }
    if (k.contains('fe')) return [VidaTags.fe];
    if (k.contains('amor')) return [VidaTags.amor];
    if (k.contains('paz')) return [VidaTags.paz];
    if (k.contains('orac')) return [VidaTags.oracion];
    if (k.contains('sabid')) return [VidaTags.sabiduria];
    return [VidaTags.esperanza];
  }

  static List<String> _mapBook(String book) {
    final b = book.toLowerCase();
    if (b.contains('salmo')) return [VidaTags.oracion, VidaTags.paz];
    if (b.contains('proverb')) return [VidaTags.sabiduria];
    if (b.contains('job')) return [VidaTags.tristeza, VidaTags.paciencia];
    if (b.contains('juan') || b.contains('romanos')) {
      return [VidaTags.amor, VidaTags.fe];
    }
    if (b.contains('filip')) return [VidaTags.gozo, VidaTags.paz];
    if (b.contains('apocalip')) return [VidaTags.esperanza];
    return [VidaTags.fe];
  }

  static List<String> _mapEvent(String e) {
    switch (e) {
      case 'evangelizate':
        return [VidaTags.proposito, VidaTags.fe];
      case 'arcade':
        return [VidaTags.gozo];
      case 'favorito':
        return [VidaTags.fe];
      case 'comunidad':
        return [VidaTags.amor, VidaTags.soledad];
      default:
        return [VidaTags.esperanza];
    }
  }
}
