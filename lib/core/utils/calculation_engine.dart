import 'package:decimal/decimal.dart';
import '../constants/app_constants.dart';

class CalculationEngine {
  CalculationEngine._();

  /// Average Power Factor = kWh / kVAh (strictly bounded 0.000 to 1.000)
  static double calculatePowerFactor(double kwh, double kvah) {
    if (kvah <= 0 || kwh <= 0) return 0.000;
    final pf = kwh / kvah;
    return (pf.clamp(0.000, 1.000) * 1000).roundToDouble() / 1000;
  }

  /// Estimated per-reading Bill (₹):
  ///   Units = consumed_kwh × multiplyingFactor (5)
  ///   Bill  = Units × tariffPerUnit (₹8.68)
  static double calculateEstimatedBill({
    required double kwh,
    double mdRecorded = 0,
    double? powerFactor,
    double energyRate = AppConstants.tariffPerUnit,
    double demandRate = 0,
    double pfThreshold = AppConstants.pfPenaltyThreshold,
  }) {
    final units = Decimal.fromInt((kwh * AppConstants.multiplyingFactor).round());
    final total = units * Decimal.parse(energyRate.toStringAsFixed(2));
    return total.toDouble();
  }

  /// Contract demand breach check
  static bool isNearContractDemandBreach(
    double mdRecorded, {
    double contractDemand = AppConstants.defaultContractDemandKva,
    double threshold = AppConstants.mdWarningThresholdKva,
  }) {
    return mdRecorded >= threshold;
  }

  /// Reactive penalty risk check
  static bool hasReactivePenaltyRisk(double powerFactor) {
    return powerFactor < AppConstants.pfPenaltyThreshold;
  }

  /// Format INR currency
  static String formatInr(double amount) {
    final value = amount.round();
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}
