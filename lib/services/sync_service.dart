import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/database_helper.dart';
import '../models/site.dart';
import '../models/panel.dart';
import '../models/meter.dart';
import '../models/reading.dart';
import '../models/contract_demand.dart';
import '../models/analysis_result.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();
  final SupabaseClient _supabase;
  final Connectivity _connectivity = Connectivity();
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  StreamSubscription? _connectivitySub;

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  SyncService(this._supabase);

  void startMonitoring() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncAll();
      }
    });
  }

  void stopMonitoring() {
    _connectivitySub?.cancel();
  }

  Future<bool> syncAll() async {
    _status = SyncStatus.syncing;
    _lastError = null;

    try {
      await _syncTable<Site>(
        'sites',
        Site.fromMap,
        (s) => s.toJson(),
        'sites',
      );
      await _syncTable<Panel>(
        'panels',
        Panel.fromMap,
        (p) => p.toJson(),
        'panels',
      );
      await _syncTable<Meter>(
        'meters',
        Meter.fromMap,
        (m) => m.toJson(),
        'meters',
      );
      await _syncTable<Reading>(
        'readings',
        Reading.fromMap,
        (r) => r.toJson(),
        'readings',
      );
      await _syncTable<ContractDemand>(
        'contract_demands',
        ContractDemand.fromMap,
        (c) => c.toJson(),
        'contract_demands',
      );
      await _syncTable<AnalysisResult>(
        'analysis_results',
        AnalysisResult.fromMap,
        (a) => a.toJson(),
        'analysis_results',
      );

      _status = SyncStatus.success;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _status = SyncStatus.error;
      return false;
    }
  }

  Future<void> _syncTable<T>(
    String localTable,
    T Function(Map<String, dynamic>) fromMap,
    Map<String, dynamic> Function(T) toJson,
    String remoteTable,
  ) async {
    final rows = await _db.getPendingSyncRows(localTable);
    if (rows.isEmpty) return;

    for (final row in rows) {
      final id = row['id'] as String;
      final item = fromMap(row);

      try {
        await _supabase.from(remoteTable).upsert(toJson(item));
        await _db.markSynced(localTable, id);
      } catch (e) {
        // Log and continue with next row
        _lastError = 'Sync error for $localTable/$id: $e';
      }
    }
  }

  Future<List<T>> fetchRemote<T>(
    String table,
    T Function(Map<String, dynamic>) fromJson, {
    String? userId,
  }) async {
    try {
      var query = _supabase.from(table).select();
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      final data = await query;
      return (data as List).map((d) => fromJson(d as Map<String, dynamic>)).toList();
    } catch (e) {
      _lastError = 'Fetch error: $e';
      return [];
    }
  }

  Future<bool> pushToRemote<T>(
    String table,
    Map<String, dynamic> Function(T) toJson,
    T item,
  ) async {
    try {
      await _supabase.from(table).upsert(toJson(item));
      return true;
    } catch (e) {
      _lastError = 'Push error: $e';
      return false;
    }
  }
}
