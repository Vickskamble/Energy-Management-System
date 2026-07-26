import 'package:sembast/sembast.dart';
import '../../../core/database/database_factory.dart';
import '../../../core/error/exceptions.dart';
import '../../models/meter_model.dart';

class MeterLocalDatasource {
  Database? _database;
  static const String _storeName = 'meters';

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await getDatabaseFactory().openDatabase('ems_meters.db');
    return _database!;
  }

  StoreRef<String, Map<String, Object?>> get _store =>
      stringMapStoreFactory.store(_storeName);

  Future<void> insertMeter(MeterModel meter) async {
    try {
      final db = await _db;
      await _store.record(meter.id).put(db, meter.toMap());
    } catch (e) {
      throw const LocalStorageException('Unable to save meter. Please try again.');
    }
  }

  Future<List<MeterModel>> getAllMeters() async {
    try {
      final db = await _db;
      final records = await _store.find(db, finder: Finder(
        sortOrders: [SortOrder('name')],
      ));
      return records
          .map((r) => MeterModel.fromMap(r.value.cast<String, Object?>()))
          .toList();
    } catch (e) {
      throw const LocalStorageException('Unable to load meters from storage.');
    }
  }

  Future<MeterModel?> getMeterById(String id) async {
    try {
      final db = await _db;
      final record = await _store.record(id).get(db);
      if (record == null) return null;
      return MeterModel.fromMap(record.cast<String, Object?>());
    } catch (e) {
      throw const LocalStorageException('Unable to load meter details.');
    }
  }

  Future<void> updateMeter(MeterModel meter) async {
    try {
      final db = await _db;
      await _store.record(meter.id).put(db, meter.toMap());
    } catch (e) {
      throw const LocalStorageException('Unable to update meter.');
    }
  }

  Future<void> deleteMeter(String id) async {
    try {
      final db = await _db;
      await _store.record(id).delete(db);
    } catch (e) {
      throw const LocalStorageException('Unable to delete meter.');
    }
  }
}
