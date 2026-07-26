import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../core/utils/calculation_engine.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
import 'energy_event.dart';
import 'energy_state.dart';

class EnergyBloc extends Bloc<EnergyEvent, EnergyState> {
  final EnergyRepository _repository;

  EnergyBloc({required EnergyRepository repository})
      : _repository = repository,
        super(const EnergyInitial()) {
    on<LoadInitialDashboardData>(_onLoadDashboard);
    on<SubmitManualReadingForm>(_onSubmitReading);
    on<SyncOfflineCachedLogs>(_onSyncCache);
  }

  // ---------------------------------------------------------------------------
  // Event: LoadInitialDashboardData
  // ---------------------------------------------------------------------------
  Future<void> _onLoadDashboard(
    LoadInitialDashboardData event,
    Emitter<EnergyState> emit,
  ) async {
    emit(const EnergyLoading());
    try {
      final dashboard = await _repository.getDashboardData();

      emit(EnergySuccess(
        logs: dashboard.logs,
        estimatedBill: dashboard.estimatedBill,
        totalConsumption:
            (dashboard.totalConsumption * 100).roundToDouble() / 100,
        activeConsumptionToday:
            (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
        currentPowerFactor:
            (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
        maxDemandPeak:
            (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
      ));
    } on AppException catch (e) {
      emit(EnergyOperationFailure(e.message));
    } catch (_) {
      emit(const EnergyOperationFailure('Failed to load dashboard. Check your connection and try again.'));
    }
  }

  // ---------------------------------------------------------------------------
  // Event: SubmitManualReadingForm  —  Core Business Engine
  // ---------------------------------------------------------------------------
  Future<void> _onSubmitReading(
    SubmitManualReadingForm event,
    Emitter<EnergyState> emit,
  ) async {
    emit(const EnergyLoading());

    try {
      // ── Step 1: Validate inputs ─────────────────────────────────────────
      _validateFormInputs(event);

      // ── Step 2: Calculate consumed values ────────────────────────────────
      final consumedKwh = event.currentKwh - event.previousKwh;
      final consumedKvah = event.currentKvah - event.previousKvah;

      _validateConsumedValues(consumedKwh, consumedKvah);

      // ── Step 3: Compute derived metrics ─────────────────────────────────
      final powerFactor = CalculationEngine.calculatePowerFactor(
        consumedKwh,
        consumedKvah,
      );

      // ── Step 4: Build domain model ───────────────────────────────────────
      final model = EnergyLogModel.create(
        meterName: event.meterName,
        kwh: consumedKwh,
        kvah: consumedKvah,
        rkvarhLag: event.rkvarhLag,
        rkvarhLead: event.rkvarhLead,
        powerFactor: powerFactor,
        mdRecorded: event.mdRecorded,
        contractDemand: AppConstants.defaultContractDemandKva,
        loggedAt: event.loggedAt,
      );

      // ── Step 5: Persist locally (offline-first, is_synced = false) ──────
      await _repository.saveReading(model);

      // ── Step 6: Reload dashboard data ───────────────────────────────────
      final dashboard = await _repository.getDashboardData();

      emit(EnergySuccess(
        logs: dashboard.logs,
        estimatedBill: dashboard.estimatedBill,
        totalConsumption:
            (dashboard.totalConsumption * 100).roundToDouble() / 100,
        activeConsumptionToday:
            (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
        currentPowerFactor:
            (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
        maxDemandPeak:
            (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
      ));
    } on ValidationException catch (e) {
      emit(EnergyValidationError(e.message));
    } on AppException catch (e) {
      emit(EnergyOperationFailure(e.message));
    } catch (_) {
      emit(const EnergyOperationFailure('Failed to save reading. Please verify the values and try again.'));
    }
  }

  // ---------------------------------------------------------------------------
  // Event: SyncOfflineCachedLogs
  // ---------------------------------------------------------------------------
  Future<void> _onSyncCache(
    SyncOfflineCachedLogs event,
    Emitter<EnergyState> emit,
  ) async {
    emit(const EnergyLoading());
    try {
      await _repository.syncUnsyncedLogs();

      // Reload dashboard after sync
      final dashboard = await _repository.getDashboardData();

      emit(EnergySuccess(
        logs: dashboard.logs,
        estimatedBill: dashboard.estimatedBill,
        totalConsumption:
            (dashboard.totalConsumption * 100).roundToDouble() / 100,
        activeConsumptionToday:
            (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
        currentPowerFactor:
            (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
        maxDemandPeak:
            (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
      ));
    } on AppException catch (_) {
      // On sync failure, still emit success with current local data
      try {
        final dashboard = await _repository.getDashboardData();
        emit(EnergySuccess(
          logs: dashboard.logs,
          estimatedBill: dashboard.estimatedBill,
          totalConsumption:
              (dashboard.totalConsumption * 100).roundToDouble() / 100,
          activeConsumptionToday:
              (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
          currentPowerFactor:
              (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
          maxDemandPeak:
              (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
        ));
      } catch (_) {
        emit(const EnergyOperationFailure('Sync failed. Data will sync automatically when connection is available.'));
      }
    } catch (_) {
      emit(const EnergyOperationFailure('Sync failed. Data will sync automatically when connection is available.'));
    }
  }

  // ---------------------------------------------------------------------------
  // Validation Guards
  // ---------------------------------------------------------------------------

  /// Validate all form inputs before processing
  void _validateFormInputs(SubmitManualReadingForm event) {
    if (event.meterName.trim().isEmpty) {
      throw const ValidationException('Meter name cannot be empty');
    }

    if (event.currentKwh < 0) {
      throw const ValidationException('Current kWh cannot be negative');
    }
    if (event.previousKwh < 0) {
      throw const ValidationException('Previous kWh cannot be negative');
    }
    if (event.currentKvah < 0) {
      throw const ValidationException('Current kVAh cannot be negative');
    }
    if (event.previousKvah < 0) {
      throw const ValidationException('Previous kVAh cannot be negative');
    }
    if (event.rkvarhLag < 0) {
      throw const ValidationException('rkVARh (Lag) cannot be negative');
    }
    if (event.rkvarhLead < 0) {
      throw const ValidationException('rkVARh (Lead) cannot be negative');
    }
    if (event.mdRecorded < 0) {
      throw const ValidationException('MD Recorded cannot be negative');
    }
    if (event.loggedAt.isAfter(DateTime.now())) {
      throw const ValidationException('Reading date cannot be in the future');
    }

    // Guard: Current reading must be >= previous reading
    if (event.currentKwh < event.previousKwh) {
      throw ValidationException(
        'Current kWh (${event.currentKwh}) must be ≥ '
        'previous kWh (${event.previousKwh}). '
        'Check meter reading — cumulative values cannot decrease.',
      );
    }

    if (event.currentKvah < event.previousKvah) {
      throw ValidationException(
        'Current kVAh (${event.currentKvah}) must be ≥ '
        'previous kVAh (${event.previousKvah}). '
        'Check meter reading — cumulative values cannot decrease.',
      );
    }
  }

  /// Validate that consumed (derived) values are physically meaningful
  void _validateConsumedValues(double consumedKwh, double consumedKvah) {
    if (consumedKwh <= 0) {
      throw const ValidationException(
        'Consumed kWh must be positive. '
        'Current reading must be greater than previous reading.',
      );
    }
    if (consumedKvah <= 0) {
      throw const ValidationException(
        'Consumed kVAh must be positive. '
        'Current reading must be greater than previous reading.',
      );
    }
  }

}
