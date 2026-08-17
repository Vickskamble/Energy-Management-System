import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String? _lastAlertKey;
  DateTime? _lastAlertAt;

  static const String _channelId = 'ems_alerts';
  static const String _channelName = 'EMS Alerts';
  static const String _channelDesc = 'Alerts for PF penalty, MD breach, etc.';

  /// Must match the AppUserModelID set on the installer shortcuts
  /// (release/ems_installer.iss) — Windows toast notifications need a
  /// Start Menu shortcut with the same AUMID to be deliverable.
  static const String _windowsAppId = 'PowerEMS.EMS';

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      const windowsSettings = WindowsInitializationSettings(
        appName: 'PowerEMS',
        appUserModelId: _windowsAppId,
        guid: '8F2C9E5A-4B3D-4A67-9C1E-1D6F0A7B8C2E',
      );
      await _plugin.initialize(
        settings: const InitializationSettings(windows: windowsSettings),
      );
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
      // Android 13+ (API 33) requires the runtime POST_NOTIFICATIONS
      // permission — without it notifications are silently dropped.
      await androidPlatform.requestNotificationsPermission();
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

    // Suppress identical alerts re-firing on every dashboard auto-refresh.
    final key = '$id|$title|$body';
    final now = DateTime.now();
    if (_lastAlertKey == key &&
        _lastAlertAt != null &&
        now.difference(_lastAlertAt!).inSeconds < 60) {
      return;
    }
    _lastAlertKey = key;
    _lastAlertAt = now;

    if (defaultTargetPlatform == TargetPlatform.windows) {
      const windowsDetails = WindowsNotificationDetails();
      const details = NotificationDetails(windows: windowsDetails);
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return;
    }

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

  Future<void> showPfAlert(
    double pf, {
    required String meterName,
    String? site,
  }) =>
      showAlert(
        id: 1,
        title: '⚠️ Low Power Factor — $meterName',
        body: '${_scopeLabel(meterName, site)}'
            'PF is ${pf.toStringAsFixed(3)} (below 0.95). '
            'Check APFC panel to avoid 5% reactive penalty on your bill.',
      );

  Future<void> showMdAlert(
    double md,
    double limit, {
    required String meterName,
    String? site,
  }) =>
      showAlert(
        id: 2,
        title: '⚠️ MD Breach Risk — $meterName',
        body: '${_scopeLabel(meterName, site)}'
            'MD at ${md.toStringAsFixed(1)} kW, approaching '
            '$limit kW contract limit. '
            'Shift non-essential loads to off-peak hours.',
      );

  /// "Meter \"X\" (Site: Y): " prefix so the client always knows which
  /// meter and site an alert belongs to.
  static String _scopeLabel(String meterName, String? site) {
    final s = (site ?? '').trim();
    return s.isEmpty
        ? 'Meter "$meterName": '
        : 'Meter "$meterName" (Site: $s): ';
  }

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
