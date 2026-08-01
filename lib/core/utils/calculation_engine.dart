import 'dart:math';
import 'package:decimal/decimal.dart';
import '../constants/app_constants.dart';

class CalculationEngine {
  CalculationEngine._();

  static double calculatePowerFactor(double kwh, double kvah) {
    if (kvah <= 0 || kwh <= 0) return 0.000;
    return (kwh / kvah).clamp(0.000, 1.000);
  }

  static double calculateEstimatedBill({
    required double kwh,
    double mdRecorded = 0,
    double? powerFactor,
    double energyRate = AppConstants.tariffPerUnit,
    double demandRate = 0,
    double pfThreshold = AppConstants.pfPenaltyThreshold,
    double multiplyingFactor = AppConstants.multiplyingFactor,
  }) {
    final units = Decimal.fromInt(
      (kwh * multiplyingFactor).round(),
    );
    final total = units * Decimal.parse(energyRate.toStringAsFixed(2));
    return total.toDouble();
  }

  static double calculateBillingDemand(
    double mdRecorded,
    double contractDemand,
  ) {
    return max(mdRecorded, contractDemand * 0.75);
  }

  static double calculateEnergyCharges(double totalUnits, double rate) {
    return totalUnits * rate;
  }

  static double calculateDemandCharges(
    double billingDemand,
    double ratePerKva,
  ) {
    return billingDemand * ratePerKva;
  }

  static double calculateFac(double totalUnits, double ratePerUnit) {
    return totalUnits * ratePerUnit;
  }

  static double calculateWheelingCharges(
    double totalUnits,
    double ratePerUnit,
  ) {
    return totalUnits * ratePerUnit;
  }

  /// Electricity duty = flat per-unit charge × total units (NOT percentage).
  static double calculateElectricityDuty(double totalUnits, double perUnit) {
    return totalUnits * perUnit;
  }

  /// Tax = flat per-unit charge × total units (NOT percentage).
  static double calculateTaxes(double totalUnits, double perUnit) {
    return totalUnits * perUnit;
  }

  static double calculatePfRebate(
    double energyCharges,
    double demandCharges,
    double powerFactor,
  ) {
    if (powerFactor >= AppConstants.pfRebateThreshold) {
      return (energyCharges + demandCharges) *
          AppConstants.pfRebatePercent /
          100;
    }
    return 0;
  }

  static double calculatePfSurcharge(
    double energyCharges,
    double demandCharges,
    double powerFactor,
  ) {
    if (powerFactor < AppConstants.pfSurchargeThreshold) {
      return (energyCharges + demandCharges) *
          AppConstants.pfSurchargePercent /
          100;
    }
    return 0;
  }

  static double calculateLoadFactor(double avgDemand, double peakDemand) {
    if (peakDemand <= 0) return 0;
    return (avgDemand / peakDemand).clamp(0.0, 1.0);
  }

  static double calculateAverageUnitCost(double netBill, double totalUnits) {
    if (totalUnits <= 0) return 0;
    return netBill / totalUnits;
  }

  static double calculateDifference(double current, double previous) {
    return current - previous;
  }

  static double calculatePercentChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous.abs()) * 100;
  }

  static bool isNearContractDemandBreach(
    double mdRecorded, {
    double contractDemand = AppConstants.defaultContractDemandKva,
    double threshold = AppConstants.mdWarningThresholdKva,
  }) {
    return mdRecorded >= threshold;
  }

  static bool hasReactivePenaltyRisk(double powerFactor) {
    return powerFactor < AppConstants.pfPenaltyThreshold;
  }

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
