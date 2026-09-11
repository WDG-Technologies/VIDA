import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BibleStudy {
  final String id;
  final String name;
  final DateTime date;
  final String book;
  final String verses;
  final String reflection;

  const BibleStudy({
    required this.id,
    required this.name,
    required this.date,
    required this.book,
    this.verses = '',
    this.reflection = '',
  });

  BibleStudy copyWith({
    String? name,
    DateTime? date,
    String? book,
    String? verses,
    String? reflection,
  }) =>
      BibleStudy(
        id: id,
        name: name ?? this.name,
        date: date ?? this.date,
        book: book ?? this.book,
        verses: verses ?? this.verses,
        reflection: reflection ?? this.reflection,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'book': book,
        'verses': verses,
        'reflection': reflection,
      };

  factory BibleStudy.fromJson(Map<String, dynamic> json) => BibleStudy(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        date: DateTime.tryParse('${json['date'] ?? ''}') ?? DateTime.now(),
        book: '${json['book'] ?? ''}',
        verses: '${json['verses'] ?? ''}',
        reflection: '${json['reflection'] ?? ''}',
      );
}

class BibleStudyService {
  static const _key = 'bible_studies';

  static List<BibleStudy> _decode(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '[]');
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => BibleStudy.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  static Future<List<BibleStudy>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key));
  }

  static Future<void> save(BibleStudy study) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key)).map((e) => e.toJson()).toList();
    list.add(study.toJson());
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> update(BibleStudy study) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key)).map((e) => e.toJson()).toList();
    final i = list.indexWhere((e) => e['id'] == study.id);
    if (i != -1) {
      list[i] = study.toJson();
      await prefs.setString(_key, jsonEncode(list));
    }
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key)).map((e) => e.toJson()).toList();
    list.removeWhere((e) => e['id'] == id);
    await prefs.setString(_key, jsonEncode(list));
  }
}
