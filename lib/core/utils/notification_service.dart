import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'ems_alerts';
  static const String _channelName = 'EMS Alerts';
  static const String _channelDesc = 'Alerts for PF penalty, MD breach, etc.';

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);

    final androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlatform != null) {
      await androidPlatform.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_initialized) await initialize();
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showPfAlert(double pf) => showAlert(
    id: 1,
    title: '⚠️ Low Power Factor Penalty',
    body:
        'PF is ${pf.toStringAsFixed(3)} (below 0.95). '
        'Check APFC panel to avoid 5% reactive penalty on your bill.',
  );

  Future<void> showMdAlert(double md, double limit) => showAlert(
    id: 2,
    title: '⚠️ Near Maximum Demand Breach',
    body:
        'MD at ${md.toStringAsFixed(1)} kW, approaching '
        '${limit.toStringAsFixed(0)} kW contract limit. '
        'Shift non-essential loads to off-peak hours.',
  );

  Future<void> showSyncCompleteAlert(int count) => showAlert(
    id: 3,
    title: '☁️ Sync Complete',
    body: '$count offline reading(s) synced to cloud.',
  );

  Future<void> showReadingReminder() => showAlert(
    id: 4,
    title: '📝 Reading Due',
    body:
        'Month is ending and no reading has been recorded yet — '
        'record today to keep the bill estimate accurate.',
  );
}
