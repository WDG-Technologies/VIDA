import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _countKey = 'streak_count';
  static const _lastDateKey = 'last_open_date';
  static const _bestKey = 'best_streak';
  static const _datesKey = 'streak_dates';

  static Future<int> getCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countKey) ?? 0;
  }

  static Future<int> getBest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestKey) ?? 0;
  }

  static List<String> _decodeDates(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '[]');
      if (decoded is! List) return [];
      return decoded.map((e) => '$e').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> getDates() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeDates(prefs.getString(_datesKey)).toSet();
  }

  static Future<void> checkAndUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();

    final lastDate = prefs.getString(_lastDateKey) ?? '';
    if (lastDate == today) return;

    final count = prefs.getInt(_countKey) ?? 0;
    final best = prefs.getInt(_bestKey) ?? 0;
    final dates = _decodeDates(prefs.getString(_datesKey));

    final int newCount;
    if (lastDate == _yesterday()) {
      newCount = count + 1;
    } else {
      newCount = 1;
    }

    dates.add(today);
    final newBest = newCount > best ? newCount : best;

    await prefs.setInt(_countKey, newCount);
    await prefs.setString(_lastDateKey, today);
    await prefs.setInt(_bestKey, newBest);
    await prefs.setString(_datesKey, jsonEncode(dates));
  }

  static String _today() => _format(DateTime.now());

  static String _yesterday() =>
      _format(DateTime.now().subtract(const Duration(days: 1)));

  static String _format(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
