import 'dart:js_interop';

import 'package:web/web.dart' as web;

void showWebBrowserNotification(String title, String body) {
  try {
    web.Notification.requestPermission().toDart;
    final permission = web.Notification.permission;
    if (permission == 'granted') {
      final options = web.NotificationOptions(body: body);
      web.Notification(title, options);
    }
  } catch (_) {}
}
