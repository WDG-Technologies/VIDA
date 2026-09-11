import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/daily_verse.dart';
import 'web_alerts.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String _tzId = 'America/Mexico_City';
  static final List<String> _debugLog = <String>[];

  static const _motivationalId = 1001;
  static const _dailyVerseIdBase = 1010;
  static const _dailyVerseHorizonDays = 7;
  static const _testId = 1003;
  static const _testVerseId = 1004;
  static const _hour = 10;
  static const _minute = 0;
  static const _dailyHour = 8;
  static const _dailyMinute = 0;
  static const _kAwayEnabled = 'notif_away_enabled';
  static const _kDailyVerseEnabled = 'notif_daily_verse_enabled';
  static const _kDebugTrail = 'notif_debug_trail';

  static const _chMotivation = 'vida_motivation';
  static const _chCommunity = 'vida_community';
  static const _chDaily = 'vida_daily_verse';

  /// Callback para abrir deep links desde notificaciones (p. ej. Comunidad).
  static void Function(Uri uri)? openDeepLink;

  static const _motivationalMessages = [
    'Dios no se ha olvidado de ti. Vuelve a casa, Él te espera.',
    'Aunque el tiempo pase, Su amor no cambia. Vuelve a Él.',
    'No importa cuánto tiempo haya pasado, Dios sigue a tu lado.',
    'Él nunca se aleja. Da el primer paso y regresa a Su presencia.',
    'Cada día es una nueva oportunidad para volver a Dios.',
  ];

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _chMotivation,
      'Motivación',
      channelDescription: 'Recordatorios espirituales',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_vida',
      color: Color(0xFF059669),
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const _communityDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _chCommunity,
      'Comunidad',
      channelDescription: 'Likes y respuestas en Comunidad',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_vida',
      color: Color(0xFF059669),
      category: AndroidNotificationCategory.social,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static NotificationDetails _dailyDetailsFor(String title, String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _chDaily,
        'Versículo del día',
        channelDescription: 'Recordatorio diario del versículo',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_vida',
        color: const Color(0xFF059669),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'VIDA',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static void _d(String msg) {
    final line = '${DateTime.now().toIso8601String()} $msg';
    _debugLog.add(line);
    if (_debugLog.length > 80) {
      _debugLog.removeRange(0, _debugLog.length - 80);
    }
    debugPrint('[VIDA:Notif] $msg');
    // Persist last trail best-effort (no await in hot path).
    SharedPreferences.getInstance().then((p) {
      p.setStringList(_kDebugTrail, List<String>.from(_debugLog));
    }).catchError((_) {});
  }

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    _d('init() start');

    await _configureLocalTimeZone();

    // Iconos candidatos: el shrinker de release a veces elimina drawables
    // solo referenciados desde Dart → fallback a launcher.
    const iconCandidates = <String>[
      '@drawable/ic_stat_vida',
      '@mipmap/ic_launcher',
    ];

    Object? lastErr;
    for (final icon in iconCandidates) {
      try {
        final settings = InitializationSettings(
          android: AndroidInitializationSettings(icon),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        );
        await _plugin.initialize(
          settings: settings,
          onDidReceiveNotificationResponse: (resp) {
            _d('tap payload=${resp.payload}');
            final p = resp.payload;
            if (p == null || p.isEmpty) return;
            final uri = Uri.tryParse(p);
            if (uri != null) openDeepLink?.call(uri);
          },
        );
        _d('initialize ok icon=$icon');
        lastErr = null;
        break;
      } catch (e) {
        lastErr = e;
        _d('initialize FAIL icon=$icon: $e');
      }
    }
    if (lastErr != null) {
      throw lastErr!;
    }

    await _ensureAndroidChannels();
    _initialized = true;
    _d('init() ok tz=$_tzId');
  }

  static Future<void> _configureLocalTimeZone() async {
    tzdata.initializeTimeZones();
    var id = 'America/Mexico_City';
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final raw = info.identifier.trim();
      if (raw.isNotEmpty) id = raw;
      _d('device tz raw=$raw');
    } catch (e) {
      _d('FlutterTimezone fail: $e');
    }

    try {
      tz.setLocalLocation(tz.getLocation(id));
      _tzId = id;
      return;
    } catch (e) {
      _d('getLocation($id) fail: $e');
    }

    const aliases = <String, String>{
      'Mexico_City': 'America/Mexico_City',
      'US/Central': 'America/Chicago',
      'US/Eastern': 'America/New_York',
      'US/Pacific': 'America/Los_Angeles',
      'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
    };
    final mapped = aliases[id] ?? id;
    try {
      tz.setLocalLocation(tz.getLocation(mapped));
      _tzId = mapped;
      return;
    } catch (e) {
      _d('alias $mapped fail: $e');
    }

    try {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
      _tzId = 'America/Mexico_City';
    } catch (e) {
      _d('fallback UTC: $e');
      tz.setLocalLocation(tz.UTC);
      _tzId = 'UTC';
    }
  }

  static Future<void> _ensureAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      _d('no Android plugin impl');
      return;
    }
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chMotivation,
        'Motivación',
        description: 'Recordatorios espirituales',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chCommunity,
        'Comunidad',
        description: 'Likes y respuestas en Comunidad',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chDaily,
        'Versículo del día',
        description: 'Recordatorio diario del versículo',
        importance: Importance.high,
      ),
    );
    _d('channels created');
  }

  /// Pide permiso de notificaciones + alarmas exactas (Android 12+/13+).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return WebAlerts.requestPermission();
    if (!_initialized) await init();

    var granted = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final n = await android.requestNotificationsPermission();
      _d('requestNotificationsPermission=$n');
      if (n == false) granted = false;
      try {
        final exact = await android.requestExactAlarmsPermission();
        _d('requestExactAlarmsPermission=$exact');
      } catch (e) {
        _d('requestExactAlarmsPermission err: $e');
      }
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final n = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _d('ios requestPermissions=$n');
      if (n == false) granted = false;
    }
    return granted;
  }

  static Future<bool> areNotificationsAllowed() async {
    if (kIsWeb) return WebAlerts.isGranted();
    if (!_initialized) await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final v = await android.areNotificationsEnabled() ?? true;
      _d('areNotificationsEnabled=$v');
      return v;
    }
    return true;
  }

  static Future<void> showCommunity({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (body.trim().isEmpty) return;
    if (kIsWeb) {
      await WebAlerts.show(title: title, body: body);
      return;
    }
    if (!_initialized) await init();
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: _communityDetails,
        payload: payload,
      );
      _d('showCommunity ok');
    } catch (e) {
      _d('showCommunity fail: $e');
    }
  }

  /// Aviso inmediato para comprobar permisos/canal.
  static Future<bool> showTestNotification() async {
    if (kIsWeb) {
      await WebAlerts.show(
        title: 'VIDA',
        body: 'Los avisos del navegador están activos',
      );
      return true;
    }
    if (!_initialized) await init();
    final ok = await requestPermission();
    if (!ok && !await areNotificationsAllowed()) {
      _d('showTest aborted: permission denied');
      return false;
    }
    try {
      await _plugin.show(
        id: _testId,
        title: 'VIDA · debug',
        body:
            'OK · tz=$_tzId · ${DateTime.now().toIso8601String()}',
        notificationDetails: _details,
      );
      _d('showTest ok');
      return true;
    } catch (e) {
      _d('showTest fail: $e');
      return false;
    }
  }

  /// Muestra YA el versículo del día (texto completo) y reprograma la cola.
  static Future<bool> showTodayVerseNow() async {
    if (kIsWeb) {
      final v = await DailyVerseService.forToday();
      await WebAlerts.show(
        title: v.referencia,
        body: v.versiculo,
      );
      return true;
    }
    if (!_initialized) await init();
    final ok = await requestPermission();
    if (!ok && !await areNotificationsAllowed()) return false;

    final verse = await DailyVerseService.forToday();
    final title = verse.referencia;
    final body = _clip(verse.versiculo);
    try {
      await _plugin.show(
        id: _testVerseId,
        title: title,
        body: body,
        notificationDetails: _dailyDetailsFor(title, body),
        payload: 'vida://inicio',
      );
      _d('showTodayVerseNow ok ref=$title');
      await scheduleDailyVerseReminder();
      return true;
    } catch (e) {
      _d('showTodayVerseNow fail: $e');
      return false;
    }
  }

  static Future<void> scheduleAwayReminder() async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    await _plugin.cancel(id: _motivationalId);
    if (!await areAwayRemindersEnabled()) {
      _d('away disabled — skip');
      return;
    }
    if (!await areNotificationsAllowed()) {
      _d('away skip: not allowed');
      return;
    }

    final when = _nextAwaySlot();
    final message = _messageFor(when);
    final ok = await _zonedScheduleSafe(
      id: _motivationalId,
      title: 'VIDA',
      body: message,
      when: when,
      details: _details,
      // Un solo disparo; se reprograma al abrir la app.
    );
    _d('away schedule ${ok ? 'ok' : 'FAIL'} when=$when');
  }

  /// Programa el versículo real para los próximos [_dailyVerseHorizonDays] días (8:00 local).
  static Future<void> scheduleDailyVerseReminder() async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await _cancelDailyVerseSlots();
    if (!await areDailyVerseRemindersEnabled()) {
      _d('daily verse disabled — skip');
      return;
    }
    if (!await areNotificationsAllowed()) {
      _d('daily verse skip: not allowed');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _dailyHour,
      _dailyMinute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    var scheduled = 0;
    for (var i = 0; i < _dailyVerseHorizonDays; i++) {
      final when = next.add(Duration(days: i));
      final verse = await DailyVerseService.forToday(when);
      final title = verse.referencia;
      final body = _clip(verse.versiculo);
      final id = _dailyVerseIdBase + i;
      final ok = await _zonedScheduleSafe(
        id: id,
        title: title,
        body: body,
        when: when,
        details: _dailyDetailsFor(title, body),
        payload: 'vida://inicio',
      );
      _d(
        'daily[$i] id=$id ${ok ? 'ok' : 'FAIL'} '
        'when=$when ref=$title',
      );
      if (ok) scheduled++;
    }
    _d('daily verse scheduled=$scheduled/$_dailyVerseHorizonDays');
  }

  static Future<void> _cancelDailyVerseSlots() async {
    for (var i = 0; i < _dailyVerseHorizonDays; i++) {
      try {
        await _plugin.cancel(id: _dailyVerseIdBase + i);
      } catch (_) {}
    }
    // Legacy single-id from older builds.
    try {
      await _plugin.cancel(id: 1002);
    } catch (_) {}
  }

  /// Reprograma todos los recordatorios (tras abrir la app / reanudar).
  static Future<void> rescheduleAll() async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    _d('rescheduleAll()');
    await scheduleAwayReminder();
    await scheduleDailyVerseReminder();
  }

  static Future<bool> _zonedScheduleSafe({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    DateTimeComponents? match,
    String? payload,
  }) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    var canExact = false;
    try {
      canExact = await android?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      _d('canScheduleExact err: $e');
    }

    final modes = <AndroidScheduleMode>[
      if (canExact) AndroidScheduleMode.exactAllowWhileIdle,
      if (canExact) AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.inexactAllowWhileIdle,
      if (!canExact) AndroidScheduleMode.exactAllowWhileIdle,
    ];

    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: match,
          payload: payload,
        );
        _d('zonedSchedule id=$id mode=$mode OK');
        return true;
      } catch (e) {
        _d('zonedSchedule id=$id mode=$mode FAIL: $e');
      }
    }
    return false;
  }

  /// Informe completo para diagnóstico en Perfil.
  static Future<String> debugReport() async {
    if (kIsWeb) return 'Web: usa Notification API del navegador';
    if (!_initialized) {
      try {
        await init();
      } catch (e) {
        return 'init FAIL: $e';
      }
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    bool? allowed;
    bool? canExact;
    try {
      allowed = await android?.areNotificationsEnabled();
    } catch (_) {}
    try {
      canExact = await android?.canScheduleExactNotifications();
    } catch (_) {}

    List<PendingNotificationRequest> pending = const [];
    try {
      pending = await _plugin.pendingNotificationRequests();
    } catch (e) {
      _d('pendingNotificationRequests fail: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final trail = prefs.getStringList(_kDebugTrail) ?? _debugLog;

    final buf = StringBuffer()
      ..writeln('=== VIDA notif debug ===')
      ..writeln('initialized=$_initialized')
      ..writeln('tz=$_tzId')
      ..writeln('localNow=${tz.TZDateTime.now(tz.local)}')
      ..writeln('allowed=$allowed')
      ..writeln('canExact=$canExact')
      ..writeln('away=${await areAwayRemindersEnabled()}')
      ..writeln('dailyVerse=${await areDailyVerseRemindersEnabled()}')
      ..writeln('pending=${pending.length}');
    for (final p in pending) {
      buf.writeln('  • id=${p.id} title=${p.title} body=${_clip(p.body ?? '', 80)}');
    }
    try {
      final v = await DailyVerseService.forToday();
      buf.writeln('todayVerse=${v.referencia}');
      buf.writeln('todayText=${_clip(v.versiculo, 120)}');
    } catch (e) {
      buf.writeln('todayVerse ERR: $e');
    }
    buf.writeln('--- trail ---');
    for (final line in trail.take(40)) {
      buf.writeln(line);
    }
    return buf.toString();
  }

  static Future<bool> areAwayRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAwayEnabled) ?? true;
  }

  static Future<void> setAwayRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAwayEnabled, enabled);
    _d('setAway=$enabled');
    if (enabled) {
      await requestPermission();
      await scheduleAwayReminder();
    } else if (_initialized) {
      await _plugin.cancel(id: _motivationalId);
    }
  }

  static Future<bool> areDailyVerseRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDailyVerseEnabled) ?? true;
  }

  static Future<void> setDailyVerseRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyVerseEnabled, enabled);
    _d('setDailyVerse=$enabled');
    if (enabled) {
      await requestPermission();
      await scheduleDailyVerseReminder();
    } else if (_initialized) {
      await _cancelDailyVerseSlots();
    }
  }

  static Future<void> showMotivational() async {
    if (!await areAwayRemindersEnabled()) return;
    if (!_initialized) await init();
    final message = _messageFor(DateTime.now());

    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'VIDA',
        body: message,
        notificationDetails: _details,
      );
      _d('showMotivational ok');
    } catch (e) {
      _d('showMotivational fail: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notification_date', _today());
  }

  static Future<int> daysSinceLastOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_open_date') ?? '';
    if (last.isEmpty) return 0;

    DateTime? lastDay;
    final parts = last.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        lastDay = DateTime(y, m, d);
      }
    }
    lastDay ??= () {
      final p = DateTime.tryParse(last);
      if (p == null) return null;
      return DateTime(p.year, p.month, p.day);
    }();
    if (lastDay == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(lastDay).inDays;
  }

  static Future<bool> shouldShowToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotif = prefs.getString('last_notification_date') ?? '';
    return lastNotif != _today();
  }

  static tz.TZDateTime _nextAwaySlot() {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _hour,
      _minute,
    ).add(const Duration(days: 2));
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  static String _messageFor(DateTime when) =>
      _motivationalMessages[when.day % _motivationalMessages.length];

  static String _clip(String s, [int max = 280]) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
