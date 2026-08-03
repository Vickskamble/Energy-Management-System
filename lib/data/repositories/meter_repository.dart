import 'package:flutter/foundation.dart';
import '../datasources/remote/meter_remote_datasource.dart';
import '../models/meter_model.dart';

/// Cloud-only meter store backed by Supabase. Notifies listeners on every
/// change so pages (meter list, reading-entry dropdown, etc.) can refresh
/// immediately without a page reload.
class MeterRepository extends ChangeNotifier {
  final MeterRemoteDatasource _remote;

  MeterRepository({MeterRemoteDatasource? remote})
    : _remote = remote ?? MeterRemoteDatasource();

  Future<List<MeterModel>> getAllMeters() => _remote.getAllMeters();

  Future<void> saveMeter(MeterModel meter) async {
    await _remote.upsertMeter(meter);
    notifyListeners();
  }

  Future<void> updateMeter(MeterModel meter) async {
    await _remote.upsertMeter(meter);
    notifyListeners();
  }

  Future<void> deleteMeter(String id) async {
    await _remote.deleteMeter(id);
    notifyListeners();
  }

  /// Notifies listeners to re-read data (e.g. after a backup restore).
  void refresh() => notifyListeners();
}
