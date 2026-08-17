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
      final uid = _client.auth.currentUser?.id;
      var query = _client.from(_table).select('*').eq('id', id);
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      final data = await query.maybeSingle();
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
      // The `daily_kwh_target` column may not exist on older databases yet —
      // retry without it so adding a meter never fails because of the new
      // field.
      if (e is PostgrestException && e.code == 'PGRST204') {
        final json = meter.toJson()..remove('daily_kwh_target');
        try {
          await _client.from(_table).upsert(json).select().single();
          return;
        } catch (_) {
          // Fall through → generic error below.
        }
      }
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException(
        'Unable to save meter. Check your connection and try again.',
      );
    }
  }

  Future<void> deleteMeter(String id) async {
    try {
      final uid = _client.auth.currentUser?.id;
      var query = _client.from(_table).delete().eq('id', id);
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      await query;
    } catch (e) {
      if (e is RemoteStorageException) rethrow;
      throw const RemoteStorageException('Unable to delete meter.');
    }
  }
}
