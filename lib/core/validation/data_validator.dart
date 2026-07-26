import '../constants/app_constants.dart';
import '../calculation/bill_breakdown.dart';
import '../../domain/entities/energy_log_entity.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> passed;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.passed,
  });

  int get totalChecks => errors.length + warnings.length + passed.length;
  int get issueCount => errors.length + warnings.length;

  String get summary {
    if (isValid) {
      if (warnings.isEmpty) return 'All checks passed';
      return '${passed.length} passed, ${warnings.length} warnings';
    }
    return '${errors.length} errors, ${warnings.length} warnings';
  }
}

class DataValidator {
  DataValidator._();

  static ValidationResult validateReading({
    required double? kwh,
    required double? kvah,
    required double? mdRecorded,
    required double? powerFactor,
    required double? contractDemand,
    bool isRequired = true,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final passed = <String>[];

    if (kwh == null) {
      if (isRequired) errors.add('Energy (kWh) is missing');
    } else if (kwh < 0) {
      errors.add('Energy (kWh) cannot be negative (got $kwh)');
    } else if (kwh == 0) {
      warnings.add('Energy (kWh) is zero');
    } else {
      passed.add('Energy (kWh) = $kwh');
    }

    if (kvah == null) {
      if (isRequired) errors.add('Apparent Energy (kVAh) is missing');
    } else if (kvah < 0) {
      errors.add('Apparent Energy (kVAh) cannot be negative (got $kvah)');
    } else {
      passed.add('Apparent Energy (kVAh) = $kvah');
    }

    if (kwh != null && kvah != null && kvah > 0 && kwh > 0) {
      if (kwh > kvah) {
        warnings.add('kWh ($kwh) > kVAh ($kvah) — possible meter reading error');
      } else {
        passed.add('kWh <= kVAh (valid ratio)');
      }
    }

    if (mdRecorded == null) {
      if (isRequired) errors.add('Maximum Demand (MD) is missing');
    } else if (mdRecorded < 0) {
      errors.add('Maximum Demand cannot be negative (got $mdRecorded)');
    } else {
      passed.add('Maximum Demand = $mdRecorded kW');
    }

    if (contractDemand != null && mdRecorded != null && contractDemand > 0) {
      if (mdRecorded > contractDemand) {
        warnings.add('MD ($mdRecorded) exceeds Contract Demand ($contractDemand)');
      }
      if (mdRecorded > contractDemand * 0.9) {
        warnings.add('MD ($mdRecorded) is >90% of Contract Demand ($contractDemand)');
      }
    }

    if (powerFactor == null) {
      warnings.add('Power Factor is missing — will be calculated from kWh/kVAh');
    } else if (powerFactor < 0 || powerFactor > 1) {
      errors.add('Power Factor must be between 0 and 1 (got $powerFactor)');
    } else if (powerFactor < AppConstants.pfPenaltyThreshold) {
      warnings.add('PF ($powerFactor) below threshold (${AppConstants.pfPenaltyThreshold})');
    } else {
      passed.add('PF ($powerFactor) meets threshold');
    }

    if (kwh != null && kvah != null && kvah > 0) {
      final calculatedPf = (kwh / kvah).clamp(0.0, 1.0);
      if (powerFactor != null && (powerFactor - calculatedPf).abs() > 0.02) {
        warnings.add('PF mismatch: reported $powerFactor vs calculated $calculatedPf');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      passed: passed,
    );
  }

  static ValidationResult validateBillBreakdown(BillBreakdown breakdown) {
    final errors = <String>[];
    final warnings = <String>[];
    final passed = <String>[];

    if (breakdown.averageUnitCost < 0) {
      errors.add('Average unit cost is negative');
    } else {
      passed.add('Average unit cost = ₹${breakdown.averageUnitCost.toStringAsFixed(2)}');
    }

    if (breakdown.energyCharges < 0) {
      errors.add('Energy charges are negative');
    }
    if (breakdown.demandCharges < 0) {
      errors.add('Demand charges are negative');
    }

    final reconstructedTotal = breakdown.energyCharges + breakdown.demandCharges +
        breakdown.facCharges + breakdown.wheelingCharges +
        breakdown.electricityDuty + breakdown.taxes +
        breakdown.pfSurcharge - breakdown.pfRebate - breakdown.subsidy;

    if ((reconstructedTotal - breakdown.netBill).abs() > 1) {
      errors.add('Bill mismatch: reconstructed $reconstructedTotal vs reported ${breakdown.netBill}');
    } else {
      passed.add('Bill totals are consistent');
    }

    if (breakdown.powerFactor < AppConstants.pfPenaltyThreshold && breakdown.pfRebate > 0) {
      errors.add('PF rebate applied but PF (${breakdown.powerFactor}) is below threshold (${AppConstants.pfPenaltyThreshold})');
    }

    if (breakdown.powerFactor < AppConstants.pfSurchargeThreshold && breakdown.pfSurcharge <= 0) {
      warnings.add('PF below ${AppConstants.pfSurchargeThreshold} but no surcharge applied');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      passed: passed,
    );
  }

  static ValidationResult validateComparison(MonthComparison comparison) {
    final errors = <String>[];
    final warnings = <String>[];
    final passed = <String>[];

    if (comparison.previous == null) {
      warnings.add('No previous month data for comparison');
      return ValidationResult(isValid: true, errors: errors, warnings: warnings, passed: passed);
    }

    if ((comparison.current.netBill - comparison.previous!.netBill).abs() !=
        comparison.billDifference.abs()) {
      errors.add('Bill difference mismatch');
    } else {
      passed.add('Bill difference = ₹${comparison.billDifference.toStringAsFixed(0)}');
    }

    if (comparison.billPercentChange > 50) {
      warnings.add('Bill increased by ${comparison.billPercentChange.toStringAsFixed(0)}%');
    } else if (comparison.billPercentChange < -50) {
      warnings.add('Bill decreased by ${comparison.billPercentChange.toStringAsFixed(0)}%');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      passed: passed,
    );
  }

  static ValidationResult validateLogs(List<EnergyLogEntity> logs) {
    final errors = <String>[];
    final warnings = <String>[];
    final passed = <String>[];

    if (logs.isEmpty) {
      errors.add('No readings available for analysis');
      return ValidationResult(isValid: false, errors: errors, warnings: warnings, passed: passed);
    }

    passed.add('${logs.length} readings available');

    logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    for (int i = 1; i < logs.length; i++) {
      if (logs[i].kwh < logs[i - 1].kwh) {
        warnings.add('Cumulative kWh decreased from ${logs[i - 1].kwh} to ${logs[i].kwh} on ${logs[i].loggedAt}');
      }
      if (logs[i].kvah < logs[i - 1].kvah) {
        warnings.add('Cumulative kVAh decreased from ${logs[i - 1].kvah} to ${logs[i].kvah} on ${logs[i].loggedAt}');
      }
    }
    passed.add('Cumulative values are consistent');

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      passed: passed,
    );
  }
}
