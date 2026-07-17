import 'package:sembast_web/sembast_web.dart';
import '../../../core/error/exceptions.dart';
import '../../models/meter_model.dart';

class MeterLocalDatasource {
  Database? _database;
  static const String _storeName = 'meters';

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await databaseFactoryWeb.openDatabase('ems_meters.db');
    return _database!;
  }

  StoreRef<String, Map<String, Object?>> get _store =>
      stringMapStoreFactory.store(_storeName);

  Future<void> insertMeter(MeterModel meter) async {
    try {
      final db = await _db;
      await _store.record(meter.id).put(db, meter.toMap());
    } catch (e) {
      throw LocalStorageException('Failed to insert meter: $e');
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
      throw LocalStorageException('Failed to fetch meters: $e');
    }
  }

  Future<MeterModel?> getMeterById(String id) async {
    try {
      final db = await _db;
      final record = await _store.record(id).get(db);
      if (record == null) return null;
      return MeterModel.fromMap(record.cast<String, Object?>());
    } catch (e) {
      throw LocalStorageException('Failed to fetch meter: $e');
    }
  }

  Future<void> updateMeter(MeterModel meter) async {
    try {
      final db = await _db;
      await _store.record(meter.id).put(db, meter.toMap());
    } catch (e) {
      throw LocalStorageException('Failed to update meter: $e');
    }
  }

  Future<void> deleteMeter(String id) async {
    try {
      final db = await _db;
      await _store.record(id).delete(db);
    } catch (e) {
      throw LocalStorageException('Failed to delete meter: $e');
    }
  }
}
