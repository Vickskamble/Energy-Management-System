import '../config/app_config.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Wipes ALL business data for the current user from Supabase (RLS allows
/// deleting own rows): energy logs, meters, tariff settings and bill
/// reconciliation. Used by Settings > Danger Zone > Reset All Data.
class DataResetService {
  DataResetService._();

  static Future<void> resetAllData() async {
    if (!SupabaseClientManager.isInitialized) {
      AppConfig.reset();
      return;
    }
    final user = SupabaseClientManager.client.auth.currentUser;
    if (user == null) {
      AppConfig.reset();
      return;
    }
    final uid = user.id;
    final client = SupabaseClientManager.client;

    // 1. Cloud: energy logs.
    try {
      await client
          .from('energy_logs')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      AppLogger.w('Cloud reset of energy logs failed (best-effort): $e');
    }

    // 2. Cloud: meters.
    try {
      await client
          .from('user_meters')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      AppLogger.w('Cloud reset of meters failed (best-effort): $e');
    }

    // 3. Cloud: tariff settings.
    try {
      await client
          .from('user_settings')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      AppLogger.w('Cloud reset of settings failed (best-effort): $e');
    }

    // 4. Cloud: bill reconciliation.
    try {
      await client
          .from('bill_reconcile')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      AppLogger.w('Cloud reset of bills failed (best-effort): $e');
    }

    AppConfig.reset();
  }
}
