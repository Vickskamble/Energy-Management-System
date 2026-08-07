import '../../core/config/app_config.dart';
import '../../core/error/exceptions.dart';
import '../../core/network/supabase_client.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../datasources/remote/energy_log_remote_datasource.dart';
import '../models/energy_log_model.dart';

/// Cloud-only energy log store — every read/write goes straight to
/// Supabase (RLS-scoped to the signed-in user). There is no local cache.
class EnergyRepository {
  final EnergyLogRemoteDatasource _remote;

  EnergyRepository({EnergyLogRemoteDatasource? remote})
    : _remote = remote ?? EnergyLogRemoteDatasource();

  static const int _defaultFetchLimit = 2000;

  /// Get all logs from the cloud (most recent first).
  Future<List<EnergyLogEntity>> getAllLogs({int? limit}) async {
    final models = await _remote.fetchLogs(limit: limit ?? _defaultFetchLimit);
    return models.map((m) => m.toEntity()).toList();
  }

  /// Save a reading directly to Supabase.
  Future<EnergyLogEntity> saveReading(EnergyLogModel model) async {
    _ensureOnline();
    await _remote.pushLog(model);
    return model.toEntity();
  }

  /// Update an existing reading (remote upsert).
  Future<void> updateReading(EnergyLogModel model) async {
    _ensureOnline();
    await _remote.updateLog(model);
  }

  /// Delete a reading from the cloud.
  Future<void> deleteReading(String id, {bool synced = false}) async {
    _ensureOnline();
    await _remote.deleteLog(id);
  }

  /// Check for a duplicate reading on the SAME calendar date (same meter).
  /// One entry per meter per day — the previous reading for a day is the
  /// reading recorded on an earlier day, so a second entry on the same date
  /// would corrupt the consumption chain.
  Future<EnergyLogEntity?> findDuplicateReading(
    String meterName,
    DateTime loggedAt,
  ) async {
    final dayStart = DateTime(loggedAt.year, loggedAt.month, loggedAt.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final models = await _remote.fetchLogs(
      from: dayStart,
      to: dayEnd,
      meterName: meterName,
      limit: 1,
    );
    if (models.isEmpty) return null;
    return models.first.toEntity();
  }

  /// Bulk-save imported readings directly to the cloud.
  ///
  /// Dedupes against existing rows for the same (meter, date) window to avoid
  /// duplicate readings from double-submit or repeated imports
  /// (SECURITY.md gap G7). Returns the number of rows actually inserted.
  Future<int> bulkSaveReadings(List<EnergyLogModel> models) async {
    if (models.isEmpty) return 0;
    _ensureOnline();

    final toInsert = <EnergyLogModel>[];
    for (final model in models) {
      final existing = await findDuplicateReading(
        model.meterName,
        model.loggedAt,
      );
      if (existing == null) toInsert.add(model);
    }
    if (toInsert.isEmpty) return 0;

    await _remote.pushLogs(toInsert);
    return toInsert.length;
  }

  /// Get dashboard aggregate data from the cloud.
  Future<DashboardData> getDashboardData() async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final allLogs = await _remote.fetchLogs(limit: _defaultFetchLimit);
    final todayLogs = await _remote.fetchLogs(
      from: todayStart,
      to: tomorrowStart,
    );
    final monthLogs = await _remote.fetchLogs(
      from: monthStart,
      to: nextMonthStart,
    );

    double activeConsumptionToday = 0;
    double maxDemandPeak = 0;
    double totalKwh = 0;
    double totalKvah = 0;
    double latestPf = 0;

    for (final log in todayLogs) {
      activeConsumptionToday += log.kwh;
    }

    for (final log in monthLogs) {
      totalKwh += log.kwh;
      totalKvah += log.kvah;
      if (log.mdRecorded > maxDemandPeak) {
        maxDemandPeak = log.mdRecorded;
      }
    }

    if (totalKvah > 0) {
      latestPf = (totalKwh / totalKvah).clamp(0.0, 1.0);
    }

    // Actual units after applying each reading's own multiplying factor
    // (CT ratio × PT ratio of the meter it was recorded against).
    var totalConsumption = 0.0;
    for (final log in monthLogs) {
      totalConsumption += log.kwh * log.multiplyingFactor;
    }
    totalConsumption = (totalConsumption * 100).roundToDouble() / 100;

    return DashboardData(
      logs: allLogs.map((m) => m.toEntity()).toList(),
      estimatedBill: _calculateBill(totalConsumption),
      totalConsumption: totalConsumption,
      activeConsumptionToday: activeConsumptionToday,
      currentPowerFactor: latestPf,
      maxDemandPeak: maxDemandPeak,
    );
  }

  /// Get the latest reading for a meter (for form auto-fill).
  Future<EnergyLogEntity?> getLatestReading(String meterName) async {
    final models = await _remote.fetchLogs(meterName: meterName, limit: 1);
    if (models.isEmpty) return null;
    return models.first.toEntity();
  }

  /// Get the most recent reading for a meter STRICTLY BEFORE [before].
  ///
  /// The entry form uses this as the true "previous" reading for the date
  /// being entered — the latest overall reading is wrong when back-filling an
  /// older date (its previous reading is whatever was recorded before that
  /// date, not the newest entry).
  Future<EnergyLogEntity?> getPreviousReading(
    String meterName,
    DateTime before,
  ) async {
    final models = await _remote.fetchLogs(
      to: before.subtract(const Duration(seconds: 1)),
      meterName: meterName,
      limit: 1,
    );
    if (models.isEmpty) return null;
    return models.first.toEntity();
  }

  /// Get daily consumption for current month (for monthly chart).
  Future<Map<String, double>> getDailyConsumption() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final logs = await _remote.fetchLogs(from: monthStart, to: nextMonthStart);

    final daily = <String, double>{};
    for (final log in logs) {
      final dayKey =
          '${log.loggedAt.year}-${log.loggedAt.month.toString().padLeft(2, '0')}-${log.loggedAt.day.toString().padLeft(2, '0')}';
      daily.update(dayKey, (v) => v + log.kwh, ifAbsent: () => log.kwh);
    }
    return daily;
  }

  /// Cloud-only mode: every operation requires a live Supabase session.
  void _ensureOnline() {
    if (!SupabaseClientManager.isInitialized) {
      throw const RemoteStorageException('Supabase not initialized');
    }
    if (SupabaseClientManager.client.auth.currentUser == null) {
      throw const RemoteStorageException(
        'You must be signed in to save data.',
      );
    }
  }

  /// Bill = Total Units × configured tariff
  /// where Total Units = sum(consumed_kwh) × multiplyingFactor (5)
  double _calculateBill(double totalConsumption) {
    return (totalConsumption * AppConfig.tariffPerUnit * 100).roundToDouble() /
        100;
  }
}

class DashboardData {
  final List<EnergyLogEntity> logs;
  final double estimatedBill;
  final double totalConsumption;
  final double activeConsumptionToday;
  final double currentPowerFactor;
  final double maxDemandPeak;

  const DashboardData({
    required this.logs,
    required this.estimatedBill,
    required this.totalConsumption,
    required this.activeConsumptionToday,
    required this.currentPowerFactor,
    required this.maxDemandPeak,
  });
}
