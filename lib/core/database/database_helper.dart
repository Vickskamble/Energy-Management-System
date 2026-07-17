import 'dart:async';
import 'package:sembast/sembast.dart';
import 'database_factory.dart';
import '../../models/site.dart';
import '../../models/panel.dart';
import '../../models/meter.dart';
import '../../models/reading.dart';
import '../../models/contract_demand.dart';
import '../../models/analysis_result.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = getDatabaseFactory();
    return await factory.openDatabase('ems_local.db');
  }

  StoreRef<String, Map<String, Object?>> _store(String name) =>
      stringMapStoreFactory.store(name);

  Map<String, dynamic> _asDynamic(Map<String, Object?> map) =>
      map.cast<String, dynamic>();

  // ---- Sites ----
  Future<String> insertSite(Site site) async {
    final db = await database;
    final store = _store('sites');
    await store.record(site.id).put(db, site.toMap());
    return site.id;
  }

  Future<List<Site>> getSites() async {
    final db = await database;
    final store = _store('sites');
    final records = await store.find(
      db,
      finder: Finder(sortOrders: [SortOrder('name')]),
    );
    return records.map((r) => Site.fromMap(_asDynamic(r.value))).toList();
  }

  Future<Site?> getSite(String id) async {
    final db = await database;
    final store = _store('sites');
    final record = await store.record(id).get(db);
    if (record == null) return null;
    return Site.fromMap(_asDynamic(record));
  }

  Future<int> updateSite(Site site) async {
    final db = await database;
    final store = _store('sites');
    await store.record(site.id).put(db, site.toMap());
    return 1;
  }

  Future<int> deleteSite(String id) async {
    final db = await database;
    final store = _store('sites');
    await store.record(id).delete(db);
    return 1;
  }

  // ---- Panels ----
  Future<String> insertPanel(Panel panel) async {
    final db = await database;
    final store = _store('panels');
    await store.record(panel.id).put(db, panel.toMap());
    return panel.id;
  }

  Future<List<Panel>> getPanels(String siteId) async {
    final db = await database;
    final store = _store('panels');
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.equals('site_id', siteId),
        sortOrders: [SortOrder('name')],
      ),
    );
    return records.map((r) => Panel.fromMap(_asDynamic(r.value))).toList();
  }

  Future<Panel?> getPanel(String id) async {
    final db = await database;
    final store = _store('panels');
    final record = await store.record(id).get(db);
    if (record == null) return null;
    return Panel.fromMap(_asDynamic(record));
  }

  Future<int> updatePanel(Panel panel) async {
    final db = await database;
    final store = _store('panels');
    await store.record(panel.id).put(db, panel.toMap());
    return 1;
  }

  Future<int> deletePanel(String id) async {
    final db = await database;
    final store = _store('panels');
    await store.record(id).delete(db);
    return 1;
  }

  // ---- Meters ----
  Future<String> insertMeter(Meter meter) async {
    final db = await database;
    final store = _store('meters');
    await store.record(meter.id).put(db, meter.toMap());
    return meter.id;
  }

  Future<List<Meter>> getMeters(String panelId) async {
    final db = await database;
    final store = _store('meters');
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.equals('panel_id', panelId),
        sortOrders: [SortOrder('meter_number')],
      ),
    );
    return records.map((r) => Meter.fromMap(_asDynamic(r.value))).toList();
  }

  Future<Meter?> getMeter(String id) async {
    final db = await database;
    final store = _store('meters');
    final record = await store.record(id).get(db);
    if (record == null) return null;
    return Meter.fromMap(_asDynamic(record));
  }

  Future<int> updateMeter(Meter meter) async {
    final db = await database;
    final store = _store('meters');
    await store.record(meter.id).put(db, meter.toMap());
    return 1;
  }

  Future<int> deleteMeter(String id) async {
    final db = await database;
    final store = _store('meters');
    await store.record(id).delete(db);
    return 1;
  }

  // ---- Readings ----
  Future<String> insertReading(Reading reading) async {
    final db = await database;
    final store = _store('readings');
    await store.record(reading.id).put(db, reading.toMap());
    return reading.id;
  }

  Future<List<Reading>> getReadings(String meterId,
      {DateTime? from, DateTime? to, int? limit, int? offset}) async {
    final db = await database;
    final store = _store('readings');
    var filter = Filter.equals('meter_id', meterId);

    if (from != null) {
      final fromStr = from.toIso8601String().substring(0, 10);
      filter = Filter.and([
        filter,
        Filter.greaterThanOrEquals('reading_date', fromStr),
      ]);
    }
    if (to != null) {
      final toStr = to.toIso8601String().substring(0, 10);
      filter = Filter.and([
        filter,
        Filter.lessThanOrEquals('reading_date', toStr),
      ]);
    }

    final records = await store.find(
      db,
      finder: Finder(
        filter: filter,
        sortOrders: [SortOrder('reading_date', false)],
        limit: limit,
        offset: offset,
      ),
    );
    return records.map((r) => Reading.fromMap(_asDynamic(r.value))).toList();
  }

  Future<Reading?> getLatestReading(String meterId) async {
    final db = await database;
    final store = _store('readings');
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.equals('meter_id', meterId),
        sortOrders: [SortOrder('reading_date', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    return Reading.fromMap(_asDynamic(records.first.value));
  }

  Future<int> updateReading(Reading reading) async {
    final db = await database;
    final store = _store('readings');
    await store.record(reading.id).put(db, reading.toMap());
    return 1;
  }

  Future<int> deleteReading(String id) async {
    final db = await database;
    final store = _store('readings');
    await store.record(id).delete(db);
    return 1;
  }

  // ---- Contract Demands ----
  Future<String> insertContractDemand(ContractDemand cd) async {
    final db = await database;
    final store = _store('contract_demands');
    await store.record(cd.id).put(db, cd.toMap());
    return cd.id;
  }

  Future<ContractDemand?> getActiveContractDemand(String siteId) async {
    final db = await database;
    final store = _store('contract_demands');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('site_id', siteId),
          Filter.lessThanOrEquals('effective_from', today),
          Filter.or([
            Filter.custom((record) {
              final to = record['effective_to'] as String?;
              return to == null || to.compareTo(today) >= 0;
            }),
          ]),
        ]),
        sortOrders: [SortOrder('effective_from', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    return ContractDemand.fromMap(_asDynamic(records.first.value));
  }

  // ---- Analysis Results ----
  Future<String> insertAnalysisResult(AnalysisResult ar) async {
    final db = await database;
    final store = _store('analysis_results');
    await store.record(ar.id).put(db, ar.toMap());
    return ar.id;
  }

  Future<List<AnalysisResult>> getAnalysisResults(
      {String? siteId, int? limit}) async {
    final db = await database;
    final store = _store('analysis_results');
    var filter = siteId != null
        ? Filter.equals('site_id', siteId)
        : null;
    final records = await store.find(
      db,
      finder: Finder(
        filter: filter,
        sortOrders: [SortOrder('created_at', false)],
        limit: limit,
      ),
    );
    return records.map((r) => AnalysisResult.fromMap(_asDynamic(r.value))).toList();
  }

  Future<int> deleteOldAnalysisResults({int daysOld = 90}) async {
    final db = await database;
    final store = _store('analysis_results');
    final cutoff =
        DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
    final records = await store.find(
      db,
      finder: Finder(
        filter: Filter.lessThan('created_at', cutoff),
      ),
    );
    for (final r in records) {
      await store.record(r.key).delete(db);
    }
    return records.length;
  }

  // ---- Sync helpers ----
  Future<List<Map<String, dynamic>>> getPendingSyncRows(String storeName) async {
    final db = await database;
    final store = _store(storeName);
    final records = await store.find(
      db,
      finder: Finder(filter: Filter.equals('sync_pending', 1)),
    );
    return records.map((r) => _asDynamic(r.value)).toList();
  }

  Future<int> markSynced(String storeName, String id) async {
    final db = await database;
    final store = _store(storeName);
    final data = await store.record(id).get(db);
    if (data != null) {
      final mutable = Map<String, Object?>.from(data);
      mutable['sync_pending'] = 0;
      await store.record(id).put(db, mutable);
    }
    return 1;
  }
}

