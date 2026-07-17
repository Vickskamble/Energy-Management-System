import 'package:sembast/sembast.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_factory.dart';
import '../../../core/error/exceptions.dart';
import '../../models/energy_log_model.dart';

class EnergyLogLocalDatasource {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await getDatabaseFactory().openDatabase('ems_energy_logs.db');
    return _database!;
  }

  StoreRef<String, Map<String, Object?>> get _store =>
      stringMapStoreFactory.store(AppConstants.energyLogsStore);

  /// Insert a new energy log locally (offline-first)
  Future<void> insertLog(EnergyLogModel log) async {
    try {
      final db = await _db;
      await _store.record(log.id).put(db, log.toMap());
    } catch (e) {
      throw LocalStorageException('Failed to insert energy log: $e');
    }
  }

  /// Bulk insert for sync conflicts / initial seed
  Future<void> insertLogs(List<EnergyLogModel> logs) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        for (final log in logs) {
          await _store.record(log.id).put(txn, log.toMap());
        }
      });
    } catch (e) {
      throw LocalStorageException('Failed to bulk insert logs: $e');
    }
  }

  /// Get all logs sorted by logged_at descending
  Future<List<EnergyLogModel>> getAllLogs({int? limit, int? offset}) async {
    try {
      final db = await _db;
      final records = await _store.find(
        db,
        finder: Finder(
          sortOrders: [SortOrder('logged_at', false)],
          limit: limit,
          offset: offset,
        ),
      );
      return records
          .map((r) => EnergyLogModel.fromMap(
              r.value.cast<String, Object?>()))
          .toList();
    } catch (e) {
      throw LocalStorageException('Failed to fetch energy logs: $e');
    }
  }

  /// Get logs by meter name
  Future<List<EnergyLogModel>> getLogsByMeter(
    String meterName, {
    int? limit,
  }) async {
    try {
      final db = await _db;
      final records = await _store.find(
        db,
        finder: Finder(
          filter: Filter.equals('meter_name', meterName),
          sortOrders: [SortOrder('logged_at', false)],
          limit: limit,
        ),
      );
      return records
          .map((r) => EnergyLogModel.fromMap(
              r.value.cast<String, Object?>()))
          .toList();
    } catch (e) {
      throw LocalStorageException('Failed to fetch logs by meter: $e');
    }
  }

  /// Get logs within a date range
  Future<List<EnergyLogModel>> getLogsInRange({
    required DateTime from,
    required DateTime to,
    String? meterName,
  }) async {
    try {
      final db = await _db;
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();

      var filter = Filter.and([
        Filter.greaterThanOrEquals('logged_at', fromStr),
        Filter.lessThanOrEquals('logged_at', toStr),
      ]);

      if (meterName != null) {
        filter = Filter.and([filter, Filter.equals('meter_name', meterName)]);
      }

      final records = await _store.find(
        db,
        finder: Finder(
          filter: filter,
          sortOrders: [SortOrder('logged_at', false)],
        ),
      );
      return records
          .map((r) => EnergyLogModel.fromMap(
              r.value.cast<String, Object?>()))
          .toList();
    } catch (e) {
      throw LocalStorageException('Failed to fetch logs in range: $e');
    }
  }

  /// Get latest log for a meter
  Future<EnergyLogModel?> getLatestLog(String meterName) async {
    try {
      final db = await _db;
      final records = await _store.find(
        db,
        finder: Finder(
          filter: Filter.equals('meter_name', meterName),
          sortOrders: [SortOrder('logged_at', false)],
          limit: 1,
        ),
      );
      if (records.isEmpty) return null;
      return EnergyLogModel.fromMap(
          records.first.value.cast<String, Object?>());
    } catch (e) {
      throw LocalStorageException('Failed to fetch latest log: $e');
    }
  }

  /// Get all unsynced logs (for background sync worker)
  Future<List<EnergyLogModel>> getUnsyncedLogs() async {
    try {
      final db = await _db;
      final records = await _store.find(
        db,
        finder: Finder(
          filter: Filter.equals('is_synced', 0),
          sortOrders: [SortOrder('logged_at', false)],
        ),
      );
      return records
          .map((r) => EnergyLogModel.fromMap(
              r.value.cast<String, Object?>()))
          .toList();
    } catch (e) {
      throw LocalStorageException('Failed to fetch unsynced logs: $e');
    }
  }

  /// Mark a log as synced after successful Supabase push
  Future<void> markAsSynced(String logId) async {
    try {
      final db = await _db;
      final record = _store.record(logId);
      final data = await record.get(db);
      if (data != null) {
        final mutable = Map<String, Object?>.from(data);
        mutable['is_synced'] = 1;
        await record.put(db, mutable);
      }
    } catch (e) {
      throw LocalStorageException('Failed to mark log as synced: $e');
    }
  }

  /// Delete a log locally
  Future<void> deleteLog(String logId) async {
    try {
      final db = await _db;
      await _store.record(logId).delete(db);
    } catch (e) {
      throw LocalStorageException('Failed to delete energy log: $e');
    }
  }

  /// Get total count of logs
  Future<int> getLogCount() async {
    try {
      final db = await _db;
      return await _store.count(db);
    } catch (e) {
      throw LocalStorageException('Failed to count energy logs: $e');
    }
  }
}
