class AppConstants {
  AppConstants._();

  static const String energyLogsTable = 'energy_logs';
  static const String energyLogsStore = 'energy_logs';

  static const double multiplyingFactor = 5.0;
  static const double tariffPerUnit = 6.40;
  static const double defaultContractDemandKva = 201.00;
  static const double pfPenaltyThreshold = 0.95;
  static const double mdWarningThresholdKva = 190.00;
  static const double mdWarningRatio = 0.9;
  static const double pfCriticalThreshold = 0.90;

  static const double demandChargePerKva = 650.00;
  static const double facRatePerUnit = 0.30;
  static const double wheelingChargePerUnit = 0.61;
  static const double electricityDutyPerUnit = 0.275;
  static const double taxPerUnit = 0.279;
  static const double pfRebatePercent = 1.0;
  static const double pfSurchargePercent = 5.0;
  static const double subsidyPercent = 0.0;
  static const double pfRebateThreshold = 0.95;
  static const double pfSurchargeThreshold = 0.90;
  static const double loadFactorThresholdGood = 0.75;

  /// Tolerance (%) for actual vs estimated bill reconciliation (Issue 7B).
  static const double billAccuracyTolerancePercent = 10.0;
}
