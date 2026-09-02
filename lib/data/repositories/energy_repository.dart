import '../../core/calculation/bill_calculator.dart';
import '../../core/config/app_config.dart';
import '../../core/config/subscription_config.dart';
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

  /// Throws [ReadOnlyAccountException] when the account's trial/subscription
  /// has expired (client-side mirror — the DB trigger is the hard gate).
  static Future<void> _ensureWritable() async {
    try {
      final ent = await SubscriptionStore.getEntitlement();
      if (ent.readOnly) {
        throw const ReadOnlyAccountException(
          'Your free trial has ended. Subscribe in Plan & Billing to '
          'continue recording readings.',
          code: 'ACCOUNT_READ_ONLY',
        );
      }
    } on ReadOnlyAccountException {
      rethrow;
    } catch (_) {
      // Entitlement unreachable → let the server decide (trigger blocks).
    }
  }

  /// Get all logs from the cloud (most recent first), with actual readings
  /// hydrated for legacy rows that predate the current_kwh/current_kvah
  /// columns.
  Future<List<EnergyLogEntity>> getAllLogs({int? limit}) async {
    final models = await _remote.fetchLogs(limit: limit ?? _defaultFetchLimit);
    final hydrated = EnergyLogModel.hydrateActualReadings(models);
    return hydrated.map((m) => m.toEntity()).toList();
  }

  /// Save a reading directly to Supabase.
  Future<EnergyLogEntity> saveReading(EnergyLogModel model) async {
    _ensureOnline();
    await _ensureWritable();
    await _remote.pushLog(model);
    return model.toEntity();
  }

  /// Update an existing reading (remote upsert).
  Future<void> updateReading(EnergyLogModel model) async {
    _ensureOnline();
    await _ensureWritable();
    await _remote.updateLog(model);
  }

  /// Delete a reading from the cloud.
  Future<void> deleteReading(String id, {bool synced = false}) async {
    _ensureOnline();
    await _ensureWritable();
    await _remote.deleteLog(id);
  }

  /// Bulk-update multiplying_factor + recalculate bill for all logs of a meter.
  /// Returns the number of rows updated.
  Future<int> updateMfForMeter(String meterName, double newMf) async {
    _ensureOnline();
    return _remote.updateMfForMeter(meterName, newMf);
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
    await _ensureWritable();

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
  ///
  /// Always runs [repairConsumptionChain] first so every meter's history
  /// reads as one continuous flow (consumed = current reading − previous
  /// reading), even when older/imported records stored the cumulative meter
  /// reading as the consumed value.
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
    final healed = await repairConsumptionChain(allLogs);
    final hydrated = EnergyLogModel.hydrateActualReadings(healed);

    double activeConsumptionToday = 0;
    double maxDemandPeak = 0;
    double totalKwh = 0;
    double totalKvah = 0;
    double latestPf = 0;
    for (final log in hydrated) {
      final t = log.loggedAt;
      final inMonth = !t.isBefore(monthStart) && t.isBefore(nextMonthStart);
      if (inMonth) {
        totalKwh += log.kwh;
        totalKvah += log.kvah;
        final actualMd = log.mdRecorded * log.multiplyingFactor;
        if (actualMd > maxDemandPeak) {
          maxDemandPeak = actualMd;
        }
      }
      if (!t.isBefore(todayStart) && t.isBefore(tomorrowStart)) {
        activeConsumptionToday += log.kwh;
      }
    }

    // Aggregate PF = ΣkWh ÷ ΣkVAh for the month (utility billing method).
    if (totalKvah > 0) {
      latestPf = (totalKwh / totalKvah).clamp(0.0, 1.0);
    }

    // Actual billing units after applying each reading's own multiplying
    // factor (CT ratio × PT ratio of the meter it was recorded against) —
    // always billed on kVAh (apparent energy).
    var totalConsumption = 0.0;
    for (final log in hydrated) {
      final t = log.loggedAt;
      if (!t.isBefore(monthStart) && t.isBefore(nextMonthStart)) {
        totalConsumption += log.kvah * log.multiplyingFactor;
      }
    }
    totalConsumption = (totalConsumption * 100).roundToDouble() / 100;

    // Monthly bill through the full engine (ToD slots, demand floor, taxes)
    // using the same new-engine path as Reports — the stored per-reading
    // estimate alone is no longer shown anywhere as a bill.
    final monthLogs = hydrated
        .where((m) =>
            !m.loggedAt.isBefore(monthStart) &&
            m.loggedAt.isBefore(nextMonthStart))
        .map((m) => m.toEntity())
        .toList();
    final monthKey =
        '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
    final engineBill = monthLogs.isEmpty
        ? 0.0
        : BillCalculator.calculate(
            logs: monthLogs,
            ratchetLogs: hydrated.map((m) => m.toEntity()).toList(),
            facRate: AppConfig.facRateForMonth(monthKey),
          ).netBill;

    return DashboardData(
      logs: hydrated.map((m) => m.toEntity()).toList(),
      estimatedBill: engineBill,
      totalConsumption: totalConsumption,
      activeConsumptionToday: activeConsumptionToday,
      currentPowerFactor: latestPf,
      maxDemandPeak: maxDemandPeak,
    );
  }

  /// Rebuild each meter's consumption as one continuous flow.
  ///
  /// For every row that has a stored ACTUAL (cumulative) meter reading, the
  /// consumed value is recomputed as `current reading − previous reading`.
  /// This heals/prevents the classic bug where the full cumulative reading is
  /// stored as the consumed quantity (causing month-over-month bills to spike).
  ///
  /// Rows with no stored actual reading (legacy) are left untouched — their
  /// consumed values ARE the running total and cannot be verified against a
  /// real meter value.
  ///
  /// Returns the merged list (corrected rows swapped in) and pushes the fixes
  /// back to the cloud (best-effort — failures only postpone the heal).
  Future<List<EnergyLogModel>> repairConsumptionChain(
    List<EnergyLogModel> raw,
  ) async {
    if (raw.isEmpty) return raw;
    final sorted = List<EnergyLogModel>.of(raw)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final byMeter = <String, List<EnergyLogModel>>{};
    for (final m in sorted) {
      byMeter.putIfAbsent(m.meterName, () => []).add(m);
    }

    final fixed = <EnergyLogModel>[];
    for (final rows in byMeter.values) {
      double? prevKwh;
      double? prevKvah;
      for (final r in rows) {
        final curKwh = r.currentKwh;
        final curKvah = r.currentKvah;
        if (curKwh == null) {
          // Legacy row (no stored actual reading) — its reconstructed
          // cumulative is NOT a trustworthy baseline, so it breaks the
          // chain: the next stored reading starts a fresh comparison.
          prevKwh = null;
          prevKvah = null;
        } else {
          // Only rows whose stored consumed ≈ full cumulative reading look
          // corrupted (the old import stored reading-as-consumption). Never
          // touch correctly entered rows — that would manufacture spikes on
          // healthy days.
          final corruptKwh = r.kwh > 0 && r.kwh >= curKwh * 0.8;
          final corruptKvah = curKvah != null &&
              curKvah > 0 &&
              r.kvah > 0 &&
              r.kvah >= curKvah * 0.8;
          if ((corruptKwh || corruptKvah) &&
              prevKwh != null &&
              curKwh >= prevKwh) {
            final wantKwh = corruptKwh ? round2(curKwh - prevKwh) : r.kwh;
            final wantKvah =
                (corruptKvah && prevKvah != null && curKvah >= prevKvah)
                ? round2(curKvah - prevKvah)
                : r.kvah;
            if ((wantKwh - r.kwh).abs() > 0.01 ||
                (wantKvah - r.kvah).abs() > 0.01) {
              fixed.add(
                EnergyLogModel.create(
                  id: r.id,
                  meterName: r.meterName,
                  kwh: wantKwh,
                  kvah: wantKvah,
                  currentKwh: curKwh,
                  currentKvah: curKvah,
                  rkvarhLag: r.rkvarhLag,
                  rkvarhLead: r.rkvarhLead,
                  powerFactor: r.powerFactor,
                  mdRecorded: r.mdRecorded,
                  contractDemand: r.contractDemand,
                  loggedAt: r.loggedAt,
                  isSynced: r.isSynced,
                  multiplyingFactor: r.multiplyingFactor,
                  mdValues: r.mdValues,
                ),
              );
            }
          }
          // Meter-rollover (a newer lower reading) is a new baseline — the
          // consumed value the client recorded is kept as-is.
          prevKwh = curKwh;
          prevKvah = curKvah ?? prevKvah;
        }
      }
    }

    if (fixed.isEmpty) return raw;
    try {
      _ensureOnline();
      await _remote.pushLogs(fixed);
    } catch (_) {
      // The corrected values are still used in memory below; the rows are
      // healed on the next successful run.
    }
    final byId = {for (final m in raw) m.id: m};
    for (final m in fixed) {
      byId[m.id] = m;
    }
    return byId.values.toList();
  }

  static double round2(double v) => (v * 100).roundToDouble() / 100;

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

  /// The meter's ACTUAL cumulative readings just before [before] — the
  /// values the entry form uses to compute consumed = current − previous.
  ///
  /// Uses the stored actual reading when available; legacy rows fall back to
  /// the running sum of consumed values up to that point. Returns (0, 0) for
  /// the first ever entry of a meter (consumption measured from zero).
  Future<({double kwh, double kvah})> getPreviousCumulative(
    String meterName,
    DateTime before,
  ) async {
    final logs = await _remote.fetchLogs(
      to: before.subtract(const Duration(seconds: 1)),
      meterName: meterName,
      limit: _defaultFetchLimit,
    );
    if (logs.isEmpty) return (kwh: 0.0, kvah: 0.0);
    final hydrated = EnergyLogModel.hydrateActualReadings(logs);
    final last = hydrated.last;
    return (kwh: last.currentKwh ?? 0, kvah: last.currentKvah ?? 0);
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
      throw const RemoteStorageException('You must be signed in to save data.');
    }
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
