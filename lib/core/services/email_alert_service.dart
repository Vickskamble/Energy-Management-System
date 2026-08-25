import '../config/app_config.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

class EmailAlertService {
  EmailAlertService._();

  static bool _supabaseReady() {
    if (!SupabaseClientManager.isInitialized) return false;
    return SupabaseClientManager.client.auth.currentUser != null;
  }

  static String? get _alertEmail {
    final email = AppConfig.alertEmail.trim();
    return email.isNotEmpty ? email : null;
  }

  static Future<bool> sendCriticalAlert({
    required String type,
    required String title,
    required String message,
    String? site,
    String? meter,
  }) async {
    if (!_supabaseReady()) {
      AppLogger.e('Email alert blocked: Supabase not ready (init=${SupabaseClientManager.isInitialized}, user=${SupabaseClientManager.client.auth.currentUser != null})');
      return false;
    }
    if (_alertEmail == null) {
      AppLogger.e('Email alert blocked: alertEmail not configured in Settings');
      return false;
    }
    try {
      final result = await SupabaseClientManager.client.functions
          .invoke(
            'send-alert-email',
            body: {
              'type': type,
              'severity': 'critical',
              'title': title,
              'message': message,
              'site': ?site,
              'meter': ?meter,
            },
          )
          .timeout(const Duration(seconds: 15));
      return result.data['success'] == true;
    } catch (e) {
      AppLogger.e('Failed to send critical email alert', e);
      return false;
    }
  }

  static Future<bool> sendWarningAlert({
    required String type,
    required String title,
    required String message,
    String? site,
    String? meter,
  }) async {
    if (!_supabaseReady()) {
      AppLogger.e('Warning alert blocked: Supabase not ready');
      return false;
    }
    if (_alertEmail == null) {
      AppLogger.e('Warning alert blocked: alertEmail not configured');
      return false;
    }
    try {
      final result = await SupabaseClientManager.client.functions
          .invoke(
            'send-alert-email',
            body: {
              'type': type,
              'severity': 'warning',
              'title': title,
              'message': message,
              'site': ?site,
              'meter': ?meter,
            },
          )
          .timeout(const Duration(seconds: 15));
      return result.data['success'] == true;
    } catch (e) {
      AppLogger.e('Failed to send warning email alert', e);
      return false;
    }
  }
}
