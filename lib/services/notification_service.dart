import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _motivationalId = 1001;
  static const _hour = 10;
  static const _minute = 0;
  static const _kAwayEnabled = 'notif_away_enabled';

  static const _motivationalMessages = [
    'Dios no se ha olvidado de ti. Vuelve a casa, Él te espera.',
    'Aunque el tiempo pase, Su amor no cambia. Vuelve a Él.',
    'No importa cuánto tiempo haya pasado, Dios sigue a tu lado.',
    'Él nunca se aleja. Da el primer paso y regresa a Su presencia.',
    'Cada día es una nueva oportunidad para volver a Dios.',
  ];

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'vida_motivation',
      'Motivación',
      channelDescription: 'Recordatorios espirituales',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_vida',
      largeIcon: DrawableResourceAndroidBitmap('ic_notif_large'),
      color: Color(0xFF059669),
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_vida');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Cancels and reschedules the away reminder for 2 days from now at 10:00.
  /// Repeats daily after that until the user opens the app again.
  static Future<void> scheduleAwayReminder() async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    await _plugin.cancel(id: _motivationalId);

    if (!await areAwayRemindersEnabled()) return;

    final when = _nextAwaySlot();
    final message = _messageFor(when);

    final mode = await _androidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: _motivationalId,
        title: 'VIDA',
        body: message,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<bool> areAwayRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAwayEnabled) ?? true;
  }

  static Future<void> setAwayRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAwayEnabled, enabled);
    if (enabled) {
      await requestPermission();
      await scheduleAwayReminder();
    } else if (_initialized) {
      await _plugin.cancel(id: _motivationalId);
    }
  }

  static Future<void> showMotivational() async {
    if (!await areAwayRemindersEnabled()) return;
    if (!_initialized) await init();
    final message = _messageFor(DateTime.now());

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'VIDA',
      body: message,
      notificationDetails: _details,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notification_date', _today());
  }

  static Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    try {
      final canExact = await android.canScheduleExactNotifications();
      if (canExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<int> daysSinceLastOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_open_date') ?? '';
    if (last.isEmpty) return 0;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return 0;
    return DateTime.now().difference(lastDate).inDays;
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

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
