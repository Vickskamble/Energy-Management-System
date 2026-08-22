import '../config/app_config.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Wipes the signed-in user's business data from Supabase (RLS allows
/// deleting own rows; the `delete_all_user_data` RPC is security definer
/// and also covers sessions + legacy tables atomically).
///
/// Used by:
///  - Settings > Danger Zone > Reset All Data  (keeps the account)
///  - Settings > Danger Zone > Delete Account  (full erasure, DPDP s12/13)
class DataResetService {
  DataResetService._();

  /// Deletes ALL business data rows for the current user across every
  /// table (energy logs, meters, settings, reconciliation, sessions,
  /// legacy rows) but keeps the account and subscription.
  static Future<void> resetAllData() async {
    if (!SupabaseClientManager.isInitialized) {
      AppConfig.reset();
      return;
    }
    final uid = SupabaseClientManager.client.auth.currentUser?.id;
    if (uid == null) {
      AppConfig.reset();
      return;
    }

    try {
      await SupabaseClientManager.client.rpc('delete_all_user_data');
    } catch (e) {
      // Fallback: per-table deletes (RPC may not be deployed yet).
      AppLogger.w('delete_all_user_data RPC failed, falling back: $e');
      await _fallbackDeleteOwnRows();
    }

    AppConfig.reset();
  }

  /// Full erasure: wipes every user row AND removes the account itself.
  /// Callers must sign the user out afterwards (auth session is dead).
  static Future<void> deleteAccount() async {
    if (!SupabaseClientManager.isInitialized) {
      AppConfig.reset();
      return;
    }
    final uid = SupabaseClientManager.client.auth.currentUser?.id;
    if (uid == null) {
      AppConfig.reset();
      return;
    }

    try {
      await SupabaseClientManager.client.rpc('delete_account');
    } catch (e) {
      AppLogger.w('delete_account RPC failed: $e');
      rethrow;
    }

    AppConfig.reset();
  }

  static Future<void> _fallbackDeleteOwnRows() async {
    final uid = SupabaseClientManager.client.auth.currentUser?.id;
    if (uid == null) return;
    final client = SupabaseClientManager.client;

    for (final table in const [
      'energy_logs',
      'user_meters',
      'user_settings',
      'bill_reconcile',
      'user_sessions',
      'sites',
      'panels',
      'meters',
      'readings',
      'contract_demands',
      'analysis_results',
    ]) {
      try {
        await client.from(table).delete().eq('user_id', uid);
      } catch (e) {
        AppLogger.w('Cloud reset of $table failed (best-effort): $e');
      }
    }
  }
}