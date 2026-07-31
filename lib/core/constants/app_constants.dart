class AppConstants {
  AppConstants._();

  static const String energyLogsTable = 'energy_logs';
  static const String energyLogsStore = 'energy_logs';

  static const double multiplyingFactor = 5.0;
  static const double tariffPerUnit = 8.68;
  static const double defaultContractDemandKva = 400.00;
  static const double pfPenaltyThreshold = 0.95;
  static const double mdWarningThresholdKva = 380.00;
  static const double mdWarningRatio = 0.9;
  static const double pfCriticalThreshold = 0.90;

  static const double demandChargePerKva = 320.00;
  static const double facRatePerUnit = 0.85;
  static const double wheelingChargePerUnit = 0.65;
  static const double electricityDutyPercent = 5.0;
  static const double taxPercent = 0.5;
  static const double pfRebatePercent = 1.0;
  static const double pfSurchargePercent = 5.0;
  static const double subsidyPercent = 0.0;
  static const double pfRebateThreshold = 0.95;
  static const double pfSurchargeThreshold = 0.90;
  static const double loadFactorThresholdGood = 0.75;
}
