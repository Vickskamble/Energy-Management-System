import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../core/utils/calculation_engine.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import 'energy_event.dart';
import 'energy_state.dart';

class EnergyBloc extends Bloc<EnergyEvent, EnergyState> {
  final EnergyRepository _repository;
  final MeterRepository _meterRepository;

  EnergyBloc({
    required EnergyRepository repository,
    MeterRepository? meterRepository,
  }) : _repository = repository,
       _meterRepository = meterRepository ?? MeterRepository(),
       super(const EnergyInitial()) {
    on<LoadInitialDashboardData>(_onLoadDashboard);
    on<SubmitManualReadingForm>(_onSubmitReading);
  }

  // ---------------------------------------------------------------------------
  // Event: LoadInitialDashboardData
  // ---------------------------------------------------------------------------
  Future<void> _onLoadDashboard(
    LoadInitialDashboardData event,
    Emitter<EnergyState> emit,
  ) async {
    // Silent refresh: when data already exists, skip the loading state so
    // periodic refreshes never flicker the screens.
    final hasData = state is EnergySuccess;
    final previousSuccess = state is EnergySuccess ? state as EnergySuccess : null;
    if (!hasData) emit(const EnergyLoading());
    try {
      final dashboard = await _repository.getDashboardData();

      emit(
        EnergySuccess(
          logs: dashboard.logs,
          estimatedBill: dashboard.estimatedBill,
          totalConsumption:
              (dashboard.totalConsumption * 100).roundToDouble() / 100,
          activeConsumptionToday:
              (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
          currentPowerFactor:
              (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
          maxDemandPeak: (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
          refreshFailed: false,
        ),
      );
    } on AppException catch (e) {
      if (!hasData) emit(EnergyOperationFailure(e.message));
      if (previousSuccess != null) {
        // Keep the last-known-good data visible, but tell the UI the refresh
        // failed so it no longer looks like freshly synced numbers.
        emit(previousSuccess.copyWith(refreshFailed: true));
      }
    } catch (_) {
      if (!hasData) {
        emit(
          const EnergyOperationFailure(
            'Failed to load dashboard. Check your connection and try again.',
          ),
        );
      }
      if (previousSuccess != null) {
        emit(previousSuccess.copyWith(refreshFailed: true));
      }
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

      // ── Step 2: Previous cumulative reading from the database ───────────
      // Source of truth is the DB — never trust form-supplied previous values
      // (clients could override them). consumed = current − previous.
      // When the meter has NO actual earlier reading (first entry, renamed
      // meter or legacy rows with no stored reading), the consumption for
      // THIS entry is 0 — it becomes the baseline, and units are computed
      // only when the next reading is recorded (no full-reading spikes).
      final prev = await _repository.getPreviousCumulative(
        event.meterName.trim(),
        event.loggedAt,
      );
      final hasPreviousReading = prev.kwh > 0 || prev.kvah > 0;
      final consumedKwh =
          hasPreviousReading ? event.currentKwh - prev.kwh : 0.0;
      final consumedKvah =
          hasPreviousReading ? event.currentKvah - prev.kvah : 0.0;

      if (hasPreviousReading) {
        _validateConsumedValues(consumedKwh, consumedKvah);
      }

      // ── Step 3: Duplicate guard — one reading per meter per day ─────────
      final duplicate = await _repository.findDuplicateReading(
        event.meterName.trim(),
        event.loggedAt,
      );
      if (duplicate != null) {
        final d = duplicate.loggedAt;
        throw ValidationException(
          'A reading for "${event.meterName.trim()}" already exists on '
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}. '
          'Only one entry per date is allowed — edit the existing entry '
          'instead of adding a duplicate.',
        );
      }

      // ── Step 4: Compute derived metrics ─────────────────────────────────
      // The PF recorded by the client (meter display / Excel) is stored
      // as-is and NEVER recalculated; the kWh ÷ kVAh ratio is only a
      // fallback when the client supplied no PF.
      final powerFactor = event.powerFactor ??
          CalculationEngine.calculatePowerFactor(
            consumedKwh,
            consumedKvah,
          );

      // ── Step 5: Build domain model ───────────────────────────────────────
      // Multiplying factor comes from the meter's CT/PT ratio (default
      // AppConstants.multiplyingFactor when no meter with ratios configured).
      double meterMf = AppConstants.multiplyingFactor;
      try {
        final meters = await _meterRepository.getAllMeters();
        for (final meter in meters) {
          if (meter.name == event.meterName.trim()) {
            meterMf = meter.multiplyingFactor;
            break;
          }
        }
      } catch (_) {
        // Meter lookup failed — fall back to the global default.
      }

      final model = EnergyLogModel.create(
        meterName: event.meterName,
        kwh: consumedKwh,
        kvah: consumedKvah,
        currentKwh: event.currentKwh,
        currentKvah: event.currentKvah,
        rkvarhLag: event.rkvarhLag,
        rkvarhLead: event.rkvarhLead,
        powerFactor: powerFactor,
        mdRecorded: event.mdRecorded,
        contractDemand: AppConfig.contractDemandKva,
        loggedAt: event.loggedAt,
        multiplyingFactor: meterMf,
        exportKwh: event.exportKwh,
        exportKvah: event.exportKvah,
        generationKwh: event.generationKwh,
      );

      // ── Step 6: Persist locally (offline-first, is_synced = false) ──────
      await _repository.saveReading(model);

      // ── Step 7: Reload dashboard data ───────────────────────────────────
      final dashboard = await _repository.getDashboardData();

      emit(
        EnergySuccess(
          logs: dashboard.logs,
          estimatedBill: dashboard.estimatedBill,
          totalConsumption:
              (dashboard.totalConsumption * 100).roundToDouble() / 100,
          activeConsumptionToday:
              (dashboard.activeConsumptionToday * 100).roundToDouble() / 100,
          currentPowerFactor:
              (dashboard.currentPowerFactor * 1000).roundToDouble() / 1000,
          maxDemandPeak: (dashboard.maxDemandPeak * 100).roundToDouble() / 100,
          refreshFailed: false,
        ),
      );
    } on ValidationException catch (e) {
      emit(EnergyValidationError(e.message));
    } on AppException catch (e) {
      emit(EnergyOperationFailure(e.message));
    } catch (_) {
      emit(
        const EnergyOperationFailure(
          'Failed to save reading. Please verify the values and try again.',
        ),
      );
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
    // kVAh² = kWh² + kVARh² → apparent energy can never be less than active
    // energy for import. kWh > kVAh means the reading itself is corrupt.
    if (consumedKwh > consumedKvah) {
      throw ValidationException(
        'Consumed kWh ($consumedKwh) cannot exceed kVAh ($consumedKvah) — '
        'possible meter reading error. Verify the current/previous readings.',
      );
    }
  }
}
