import 'package:freezed_annotation/freezed_annotation.dart';

part 'energy_event.freezed.dart';

@freezed
sealed class EnergyEvent with _$EnergyEvent {
  /// Load dashboard data (logs, KPIs, charts) on app start / refresh
  const factory EnergyEvent.loadInitialDashboardData() =
      LoadInitialDashboardData;

  /// Submit a manual meter reading form for a single meter
  ///
  /// Fields:
  /// - [meterName] : Unique name / identifier of the meter being read
  /// - [currentKwh] : Active energy cumulative reading from meter display
  /// - [previousKwh] : Last recorded cumulative kWh (for validation)
  /// - [currentKvah] : Apparent energy cumulative reading from meter display
  /// - [previousKvah] : Last recorded cumulative kVAh (for validation)
  /// - [rkvarhLag] : Reactive inductive component reading
  /// - [rkvarhLead] : Reactive capacitive component reading
  /// - [mdRecorded] : Maximum demand recorded since last reading (kW)
  /// - [loggedAt] : Timestamp of when the meter was read on-site
  const factory EnergyEvent.submitManualReadingForm({
    required String meterName,
    required double currentKwh,
    required double previousKwh,
    required double currentKvah,
    required double previousKvah,
    required double rkvarhLag,
    required double rkvarhLead,
    required double mdRecorded,
    required DateTime loggedAt,
  }) = SubmitManualReadingForm;

  /// Trigger a background sync of all offline-cached (is_synced = false) logs to Supabase
  const factory EnergyEvent.syncOfflineCachedLogs() = SyncOfflineCachedLogs;
}
