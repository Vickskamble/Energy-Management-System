import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/supabase_client.dart';
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
      throw RemoteStorageException('Network error pushing log: $e');
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
      throw RemoteStorageException('Network error pushing logs: $e');
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
      var query = _client
          .from(AppConstants.energyLogsTable)
          .select('*');

      if (from != null) {
        query = query.gte('logged_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lte('logged_at', to.toUtc().toIso8601String());
      }
      if (meterName != null) {
        query = query.eq('meter_name', meterName);
      }

      var ordered = query.order('logged_at', ascending: false);
      if (limit != null) ordered = ordered.limit(limit);
      if (offset != null) ordered = ordered.range(offset, offset + (limit ?? 50) - 1);

      final data = await ordered;
      return (data as List<dynamic>)
          .map((json) =>
              EnergyLogModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw RemoteStorageException('Network error fetching logs: $e');
    }
  }

  /// Fetch a single log by id
  Future<EnergyLogModel?> fetchLogById(String id) async {
    try {
      final data = await _client
          .from(AppConstants.energyLogsTable)
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return EnergyLogModel.fromJson(data);
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw RemoteStorageException('Network error fetching log: $e');
    }
  }

  /// Delete a log on remote
  Future<void> deleteLog(String id) async {
    try {
      await _client
          .from(AppConstants.energyLogsTable)
          .delete()
          .eq('id', id);
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw RemoteStorageException('Network error deleting log: $e');
    }
  }

  /// Check if Supabase is reachable (connectivity check)
  Future<bool> healthCheck() async {
    try {
      await _client
          .from(AppConstants.energyLogsTable)
          .select('id')
          .limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
