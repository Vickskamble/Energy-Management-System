import 'package:flutter/foundation.dart';
import '../datasources/local/meter_local_datasource.dart';
import '../models/meter_model.dart';

/// Meter store that notifies listeners on every change so pages (meter list,
/// reading-entry dropdown, etc.) can refresh immediately without a page reload.
class MeterRepository extends ChangeNotifier {
  final MeterLocalDatasource _local;

  MeterRepository({MeterLocalDatasource? local})
    : _local = local ?? MeterLocalDatasource();

  Future<List<MeterModel>> getAllMeters() => _local.getAllMeters();

  Future<void> saveMeter(MeterModel meter) async {
    await _local.insertMeter(meter);
    notifyListeners();
  }

  Future<void> updateMeter(MeterModel meter) async {
    await _local.updateMeter(meter);
    notifyListeners();
  }

  Future<void> deleteMeter(String id) async {
    await _local.deleteMeter(id);
    notifyListeners();
  }

  Future<void> clearLocalCache() async {
    try {
      await _local.clearAll();
    } catch (e) {
      // Cache wipe is best-effort — data re-fetches from cloud on next login.
    }
    notifyListeners();
  }
}
