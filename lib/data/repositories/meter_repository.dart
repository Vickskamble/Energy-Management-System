import '../datasources/local/meter_local_datasource.dart';
import '../models/meter_model.dart';

class MeterRepository {
  final MeterLocalDatasource _local;

  MeterRepository({MeterLocalDatasource? local})
    : _local = local ?? MeterLocalDatasource();

  Future<List<MeterModel>> getAllMeters() => _local.getAllMeters();

  Future<void> saveMeter(MeterModel meter) => _local.insertMeter(meter);

  Future<void> updateMeter(MeterModel meter) => _local.updateMeter(meter);

  Future<void> deleteMeter(String id) => _local.deleteMeter(id);

  Future<void> clearLocalCache() async {
    try {
      await _local.clearAll();
    } catch (e) {
      // Cache wipe is best-effort — data re-fetches from cloud on next login.
    }
  }
}
