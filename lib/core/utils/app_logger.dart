import 'package:flutter/foundation.dart';

/// Lightweight logging layer — visible in debug, silent in release builds.
///
/// In release mode [kReleaseMode] is true and no log lines are printed, so
/// sensitive values (user ids, tokens, error details) never reach release
/// consoles (SECURITY.md gap G10).
class AppLogger {
  AppLogger._();

  static bool get _enabled => !kReleaseMode;

  static void i(String message) {
    if (!_enabled) return;
    debugPrint('[EMS] $message');
  }

  static void e(String message, [Object? error]) {
    if (!_enabled) return;
    debugPrint('[EMS][ERROR] $message${error != null ? ' -> $error' : ''}');
  }

  static void w(String message) {
    if (!_enabled) return;
    debugPrint('[EMS][WARN] $message');
  }
}
