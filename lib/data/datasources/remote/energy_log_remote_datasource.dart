import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/energy_log_model.dart';

class EnergyLogRemoteDatasource {
  SupabaseClient get _client => SupabaseClientManager.client;

  /// Push a single log to Supabase (upsert by id)
  Future<void> pushLog(EnergyLogModel log) async {
    try {
      await _client
          .from(AppConstants.energyLogsTable)
          .upsert(log.toJson())
          .select()
          .single();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to sync data. Check your connection and try again.',
      );
    }
  }

  /// Push multiple logs in batch
  Future<void> pushLogs(List<EnergyLogModel> logs) async {
    try {
      final jsonList = logs.map((log) => log.toJson()).toList();
      await _client
          .from(AppConstants.energyLogsTable)
          .upsert(jsonList)
          .select();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      AppLogger.e('pushLogs failed', e);
      throw RemoteStorageException(
        'Unable to sync data. Check your connection and try again.',
      );
    }
  }

  /// Fetch logs from Supabase for a date range
  Future<List<EnergyLogModel>> fetchLogs({
    DateTime? from,
    DateTime? to,
    String? meterName,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client.from(AppConstants.energyLogsTable).select('*');

      // Defense-in-depth: filter by the logged-in user even though RLS
      // already scopes rows — so data stays isolated if RLS is ever
      // misconfigured or disabled.
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        query = query.eq('user_id', uid);
      }

      if (from != null) {
        query = query.gte('logged_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lt('logged_at', to.toUtc().toIso8601String());
      }
      if (meterName != null) {
        query = query.eq('meter_name', meterName);
      }

      var ordered = query.order('logged_at', ascending: false);
      if (limit != null) ordered = ordered.limit(limit);
      if (offset != null) {
        ordered = ordered.range(offset, offset + (limit ?? 50) - 1);
      }

      final data = await ordered;
      return (data as List<dynamic>)
          .map((json) => EnergyLogModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to fetch data from server. Check your connection.',
      );
    }
  }

  /// Fetch a single log by id (scoped to the logged-in user)
  Future<EnergyLogModel?> fetchLogById(String id) async {
    try {
      final uid = _client.auth.currentUser?.id;
      var query = _client
          .from(AppConstants.energyLogsTable)
          .select('*')
          .eq('id', id);
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      final data = await query.maybeSingle();

      if (data == null) return null;
      return EnergyLogModel.fromJson(data);
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException('Unable to fetch log from server.');
    }
  }

  /// Delete a log on remote (scoped to the logged-in user)
  Future<void> deleteLog(String id) async {
    try {
      final uid = _client.auth.currentUser?.id;
      var query = _client
          .from(AppConstants.energyLogsTable)
          .delete()
          .eq('id', id);
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      await query;
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException('Unable to delete log from server.');
    }
  }

  /// Update a log on remote (upsert)
  Future<void> updateLog(EnergyLogModel log) async {
    try {
      await _client
          .from(AppConstants.energyLogsTable)
          .upsert(log.toJson())
          .select()
          .single();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to update log on server. Check your connection.',
      );
    }
  }

  /// Check if Supabase is reachable (connectivity check)
  Future<bool> healthCheck() async {
    try {
      await _client.from(AppConstants.energyLogsTable).select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
