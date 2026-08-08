import 'dart:math';
import '../constants/app_constants.dart';

class EnergyCalculator {
  EnergyCalculator._();

  static double calculatePowerFactor(double kwh, double kvah) {
    if (kvah <= 0 || kwh <= 0) return 0.000;
    return (kwh / kvah).clamp(0.000, 1.000);
  }

  /// Billing demand = max(recorded MD, 11-month preceding high).
  /// The 75% of contract value is NOT part of the bill — it is only a
  /// reference level the user should stay above (shown on charts).
  static double calculateBillingDemand(
    double mdRecorded,
    double contractDemand, {
    double ratchetPeak = 0,
  }) {
    return max(mdRecorded, ratchetPeak);
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

  /// TOD charges: energy charges × (weighted average multiplier − 1).
  /// When all multipliers are 1.0, TOD charges = 0.
  static double calculateTodCharges(
    double energyCharges,
    List<double> multipliers,
  ) {
    if (multipliers.length != 4) return 0;
    final avg = multipliers.reduce((a, b) => a + b) / 4.0;
    if ((avg - 1.0).abs() < 0.0001) return 0;
    return energyCharges * (avg - 1.0);
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

  static double calculateTotalBill({
    required double energyCharges,
    required double demandCharges,
    required double facCharges,
    required double wheelingCharges,
    required double electricityDuty,
    required double taxes,
    double pfRebate = 0,
    double pfSurcharge = 0,
    double subsidy = 0,
    double todCharges = 0,
    double regionSubsidy = 0,
    double rebateSection106 = 0,
  }) {
    final subtotal =
        energyCharges + demandCharges + facCharges + wheelingCharges + todCharges;
    return (subtotal + electricityDuty + taxes + pfSurcharge) -
        pfRebate -
        subsidy -
        regionSubsidy -
        rebateSection106;
  }

  static double calculateBillHealthScore({
    required double powerFactor,
    required double loadFactor,
    required double billingDemand,
    required double contractDemand,
    required double pfSurcharge,
  }) {
    double score = 100;
    if (powerFactor < AppConstants.pfRebateThreshold) {
      score -= (AppConstants.pfRebateThreshold - powerFactor) * 100;
    }
    if (loadFactor < AppConstants.loadFactorThresholdGood) {
      score -= (AppConstants.loadFactorThresholdGood - loadFactor) * 50;
    }
    if (billingDemand > contractDemand) {
      score -= ((billingDemand - contractDemand) / contractDemand) * 30;
    }
    if (pfSurcharge > 0) score -= 15;
    return score.clamp(0, 100);
  }

  static double calculateEnergyScore({
    required double powerFactor,
    required double loadFactor,
    required double averageUnitCost,
  }) {
    double score = 100;
    if (powerFactor < AppConstants.pfRebateThreshold) score -= 20;
    if (loadFactor < AppConstants.loadFactorThresholdGood) score -= 15;
    score *= (1.0 / (1 + averageUnitCost * 0.001));
    return score.clamp(0, 100);
  }

  static double calculateDifference(double current, double previous) {
    return current - previous;
  }

  static double calculatePercentChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous.abs()) * 100;
  }
}
