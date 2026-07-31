import 'dart:math';
import '../constants/app_constants.dart';

class EnergyCalculator {
  EnergyCalculator._();

  static double calculatePowerFactor(double kwh, double kvah) {
    if (kvah <= 0 || kwh <= 0) return 0.000;
    return (kwh / kvah).clamp(0.000, 1.000);
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

  static double calculateElectricityDuty(double subtotal, double percent) {
    return subtotal * percent / 100;
  }

  static double calculateTaxes(double subtotal, double percent) {
    return subtotal * percent / 100;
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
  }) {
    final subtotal =
        energyCharges + demandCharges + facCharges + wheelingCharges;
    final duty = calculateElectricityDuty(
      subtotal,
      AppConstants.electricityDutyPercent,
    );
    final tax = calculateTaxes(subtotal + duty, AppConstants.taxPercent);
    return (subtotal + duty + tax + pfSurcharge) - pfRebate - subsidy;
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
