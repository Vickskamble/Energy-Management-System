import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/energy_log_entity.dart';

part 'energy_state.freezed.dart';

@freezed
sealed class EnergyState with _$EnergyState {
  /// Initial idle state before any event is processed
  const factory EnergyState.initial() = EnergyInitial;

  /// Processing state (loading dashboard, saving reading, or syncing)
  const factory EnergyState.loading() = EnergyLoading;

  /// Successful operation with full dashboard payload
  const factory EnergyState.success({
    /// All energy logs for the current view
    required List<EnergyLogEntity> logs,

    /// Current month estimated bill in INR (calculated)
    required double estimatedBill,

    /// Total consumption in units (kWh × multiplying factor 5)
    required double totalConsumption,

    /// Today's cumulative active energy consumption in kWh
    required double activeConsumptionToday,

    /// Average power factor across current period (0.000 – 1.000)
    required double currentPowerFactor,

    /// Maximum demand peak recorded in the current period (kW)
    required double maxDemandPeak,

    /// A background refresh failed while data was already on screen —
    /// the payload above is the last known-good snapshot. Defaults to
    /// false (no failure, fresh data).
    @Default(false) bool refreshFailed,
  }) = EnergySuccess;

  /// Form validation failed — [message] describes the specific field error
  const factory EnergyState.validationError(String message) =
      EnergyValidationError;

  /// An unrecoverable operation failure with [message]
  const factory EnergyState.operationFailure(String message) =
      EnergyOperationFailure;
}
