import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/supabase_client.dart';
import '../../models/meter_model.dart';

/// Cloud-only meter store backed by the `user_meters` table (RLS-scoped).
class MeterRemoteDatasource {
  static const String _table = 'user_meters';

  SupabaseClient get _client => SupabaseClientManager.client;

  Future<List<MeterModel>> getAllMeters() async {
    try {
      final uid = _client.auth.currentUser?.id;
      var query = _client.from(_table).select('*');
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      final data = await query.order('name', ascending: true);
      return (data as List<dynamic>)
          .map((json) => MeterModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to load meters. Check your connection and try again.',
      );
    }
  }

  Future<MeterModel?> getMeterById(String id) async {
    try {
      final data = await _client
          .from(_table)
          .select('*')
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return MeterModel.fromJson(data);
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException('Unable to load meter details.');
    }
  }

  Future<void> upsertMeter(MeterModel meter) async {
    try {
      await _client.from(_table).upsert(meter.toJson()).select().single();
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to save meter. Check your connection and try again.',
      );
    }
  }

  Future<void> deleteMeter(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException('Unable to delete meter.');
    }
  }
}
