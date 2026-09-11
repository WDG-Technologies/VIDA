import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'vida_signals.dart';
import 'vida_verse_bank.dart';

class VidaAssignment {
  final String id;
  final String reference;
  final String text;
  final List<String> tags;
  final DateTime assignedAt;
  final String insight;

  const VidaAssignment({
    required this.id,
    required this.reference,
    required this.text,
    required this.tags,
    required this.assignedAt,
    required this.insight,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'text': text,
        'tags': tags,
        'assignedAt': assignedAt.toIso8601String(),
        'insight': insight,
      };

  factory VidaAssignment.fromJson(Map<String, dynamic> json) => VidaAssignment(
        id: json['id'] as String,
        reference: json['reference'] as String,
        text: json['text'] as String,
        tags: List<String>.from(json['tags'] as List? ?? const []),
        assignedAt: DateTime.parse(json['assignedAt'] as String),
        insight: json['insight'] as String? ?? '',
      );

  factory VidaAssignment.fromBank(
    VidaBankVerse v, {
    required DateTime at,
    required String insight,
  }) =>
      VidaAssignment(
        id: v.id,
        reference: v.reference,
        text: v.text,
        tags: v.tags,
        assignedAt: at,
        insight: insight,
      );
}

class VidaAlgorithm {
  static const _kCurrent = 'vida_assignment_current';
  static const _kHistory = 'vida_assignment_history';
  static final _rng = Random();

  static Future<VidaAssignment?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCurrent);
    if (raw == null || raw.isEmpty) return null;
    try {
      return VidaAssignment.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  /// True if user may run a new assignment this calendar month.
  static Future<bool> canAssignThisMonth() async {
    final cur = await current();
    if (cur == null) return true;
    final now = DateTime.now();
    return cur.assignedAt.year != now.year ||
        cur.assignedAt.month != now.month;
  }

  static Future<DateTime?> nextAssignableDate() async {
    final cur = await current();
    if (cur == null) return null;
    final a = cur.assignedAt;
    return DateTime(a.year, a.month + 1, 1);
  }

  /// Analyzes local signals and assigns a verse (monthly).
  static Future<VidaAssignment> assign({bool force = false}) async {
    if (!force && !await canAssignThisMonth()) {
      final cur = await current();
      if (cur != null) return cur;
    }

    final weights = await VidaSignals.collect();
    final history = await _historyIds();
    final scored = <({VidaBankVerse v, double score})>[];

    for (final v in vidaVerseBank) {
      var score = 0.05;
      for (final tag in v.tags) {
        score += weights[tag] ?? 0;
      }
      // Prefer unused this year.
      if (history.contains(v.id)) score *= 0.35;
      // Slight randomness so two similar users aren't identical.
      score += _rng.nextDouble() * 0.4;
      scored.add((v: v, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(5).toList();
    final pick = top[_rng.nextInt(top.length)].v;

    final topTags = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final focus = topTags.take(2).map((e) => _label(e.key)).join(' y ');
    final insight = focus.isEmpty
        ? 'Elegido según tu actividad en la app.'
        : 'Detectamos un énfasis en $focus.';

    final assignment = VidaAssignment.fromBank(
      pick,
      at: DateTime.now(),
      insight: insight,
    );
    await _saveCurrent(assignment);
    await _pushHistory(assignment.id);
    await VidaSignals.trackEvent('vida_assign');
    assignmentChanges.bump();
    return assignment;
  }

  static final assignmentChanges = _VidaSavedNotifier();

  static Future<void> _saveCurrent(VidaAssignment a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrent, jsonEncode(a.toJson()));
  }

  static Future<List<String>> _historyIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kHistory) ?? const [];
  }

  static Future<void> _pushHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kHistory) ?? <String>[];
    list.remove(id);
    list.insert(0, id);
    while (list.length > 24) {
      list.removeLast();
    }
    await prefs.setStringList(_kHistory, list);
  }

  static String _label(String tag) {
    switch (tag) {
      case VidaTags.miedo:
        return 'valor frente al miedo';
      case VidaTags.ansiedad:
        return 'calma ante la ansiedad';
      case VidaTags.paz:
        return 'paz';
      case VidaTags.esperanza:
        return 'esperanza';
      case VidaTags.amor:
        return 'amor';
      case VidaTags.fe:
        return 'fe';
      case VidaTags.fortaleza:
        return 'fortaleza';
      case VidaTags.perdon:
        return 'perdón';
      case VidaTags.tristeza:
        return 'consuelo';
      case VidaTags.soledad:
        return 'compañía';
      case VidaTags.proposito:
        return 'propósito';
      case VidaTags.gratitud:
        return 'gratitud';
      case VidaTags.tentacion:
        return 'resistencia';
      case VidaTags.sabiduria:
        return 'sabiduría';
      case VidaTags.gozo:
        return 'gozo';
      case VidaTags.paciencia:
        return 'paciencia';
      case VidaTags.confianza:
        return 'confianza';
      case VidaTags.descanso:
        return 'descanso';
      case VidaTags.salvacion:
        return 'salvación';
      case VidaTags.oracion:
        return 'oración';
      default:
        return tag;
    }
  }
}

/// Saved VIDA verses for the Guardados tab.
class VidaSavedStore {
  static const _key = 'vida_saved_verses';
  static final changes = _VidaSavedNotifier();

  static Future<List<VidaAssignment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              VidaAssignment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> isSaved(String id) async {
    final all = await load();
    return all.any((e) => e.id == id);
  }

  static Future<void> save(VidaAssignment a) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((e) => e.id == a.id);
    all.insert(0, a);
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
    changes.bump();
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((e) => e.id == id);
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
    changes.bump();
  }
}

class _VidaSavedNotifier {
  final List<void Function()> _listeners = [];
  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void bump() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}
