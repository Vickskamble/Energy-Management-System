import '../../data/datasources/local/energy_log_local_datasource.dart';
import '../../data/datasources/local/meter_local_datasource.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../database/database_factory.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Wipes ALL app data for the current user: local sembast databases (logs,
/// meters, meta settings) plus the user's rows in Supabase (RLS allows
/// deleting own rows). Used by Settings > Danger Zone > Reset All Data.
class DataResetService {
  DataResetService._();

  static Future<void> resetAllData() async {
    // 1. Local: energy logs + meters.
    await EnergyLogLocalDatasource().clearAll();
    await MeterLocalDatasource().clearAll();

    // 2. Local: meta database (tariff, bill reconciliation, reminder flags).
    try {
      final factory = getDatabaseFactory();
      await factory.deleteDatabase('ems_meta.db');
    } catch (e) {
      AppLogger.w('Meta db reset failed (best-effort): $e');
    }
    AppConfig.reset();
    await TariffStore.load();

    // 3. Cloud: delete the current user's energy logs (own-row RLS policy).
    if (SupabaseClientManager.isInitialized) {
      final user = SupabaseClientManager.client.auth.currentUser;
      if (user != null) {
        try {
          await SupabaseClientManager.client
              .from(AppConstants.energyLogsTable)
              .delete()
              .eq('user_id', user.id);
        } catch (e) {
          AppLogger.w('Cloud reset failed (best-effort): $e');
        }
      }
    }
  }
}
