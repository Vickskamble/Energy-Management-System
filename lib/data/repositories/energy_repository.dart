import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../core/network/supabase_client.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../datasources/local/energy_log_local_datasource.dart';
import '../datasources/remote/energy_log_remote_datasource.dart';
import '../models/energy_log_model.dart';

class EnergyRepository {
  final EnergyLogLocalDatasource _local;
  final EnergyLogRemoteDatasource _remote;
  final Connectivity _connectivity;

  EnergyRepository({
    EnergyLogLocalDatasource? local,
    EnergyLogRemoteDatasource? remote,
    Connectivity? connectivity,
  })  : _local = local ?? EnergyLogLocalDatasource(),
        _remote = remote ?? EnergyLogRemoteDatasource(),
        _connectivity = connectivity ?? Connectivity();

  /// Get all logs from local storage
  Future<List<EnergyLogEntity>> getAllLogs({int? limit}) async {
    final models = await _local.getAllLogs(limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  /// Save reading locally first (offline-first)
  Future<EnergyLogEntity> saveReading(EnergyLogModel model) async {
    await _local.insertLog(model);
    return model.toEntity();
  }

  /// Get dashboard aggregate data from local storage
  Future<DashboardData> getDashboardData() async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final now = DateTime.now();
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final allLogs = await _local.getAllLogs(limit: 100);
    final todayLogs = await _local.getLogsInRange(
      from: todayStart,
      to: tomorrowStart,
    );
    final monthLogs = await _local.getLogsInRange(
      from: monthStart,
      to: nextMonthStart,
    );

    double activeConsumptionToday = 0;
    double totalKwhMonth = 0;
    double maxDemandPeak = 0;
    double totalKwh = 0;
    double totalKvah = 0;
    double latestPf = 0;

    for (final log in todayLogs) {
      activeConsumptionToday += log.kwh;
    }

    for (final log in monthLogs) {
      totalKwhMonth += log.kwh;
      totalKwh += log.kwh;
      totalKvah += log.kvah;
      if (log.mdRecorded > maxDemandPeak) {
        maxDemandPeak = log.mdRecorded;
      }
    }

    if (totalKvah > 0) {
      latestPf = (totalKwh / totalKvah).clamp(0.0, 1.0);
    }

    // Actual units after applying multiplying factor
    final totalConsumption = (totalKwhMonth * AppConstants.multiplyingFactor * 100).roundToDouble() / 100;

    return DashboardData(
      logs: allLogs.map((m) => m.toEntity()).toList(),
      estimatedBill: _calculateBill(totalConsumption),
      totalConsumption: totalConsumption,
      activeConsumptionToday: activeConsumptionToday,
      currentPowerFactor: latestPf,
      maxDemandPeak: maxDemandPeak,
    );
  }

  /// Sync unsynced local logs to Supabase
  Future<int> syncUnsyncedLogs() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResult.any(
      (r) => r != ConnectivityResult.none,
    );

    if (!hasConnection) {
      throw const NetworkException('No internet connection available');
    }

    if (!SupabaseClientManager.isInitialized) {
      throw const RemoteStorageException('Supabase not initialized');
    }

    final unsynced = await _local.getUnsyncedLogs();
    if (unsynced.isEmpty) return 0;

    await _remote.pushLogs(unsynced);

    for (final log in unsynced) {
      await _local.markAsSynced(log.id);
    }

    return unsynced.length;
  }

  /// Get the latest reading for a meter (for form auto-fill)
  Future<EnergyLogEntity?> getLatestReading(String meterName) async {
    final model = await _local.getLatestLog(meterName);
    return model?.toEntity();
  }

  /// Get daily consumption for current month (for monthly chart)
  Future<Map<String, double>> getDailyConsumption() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final logs = await _local.getLogsInRange(
      from: monthStart,
      to: nextMonthStart,
    );

    final daily = <String, double>{};
    for (final log in logs) {
      final dayKey = '${log.loggedAt.year}-${log.loggedAt.month.toString().padLeft(2, '0')}-${log.loggedAt.day.toString().padLeft(2, '0')}';
      daily.update(dayKey, (v) => v + log.kwh, ifAbsent: () => log.kwh);
    }
    return daily;
  }

  /// Bill = Total Units × ₹8.68
  /// where Total Units = sum(consumed_kwh) × multiplyingFactor (5)
  double _calculateBill(double totalConsumption) {
    return (totalConsumption * AppConstants.tariffPerUnit * 100).roundToDouble() / 100;
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
