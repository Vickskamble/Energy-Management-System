import 'package:flutter/foundation.dart';

/// Lightweight logging layer — visible in debug, tagged in release console.
class AppLogger {
  AppLogger._();

  static void i(String message) {
    debugPrint('[EMS] $message');
  }

  static void e(String message, [Object? error]) {
    debugPrint('[EMS][ERROR] $message${error != null ? ' -> $error' : ''}');
  }

  static void w(String message) {
    debugPrint('[EMS][WARN] $message');
  }
}
