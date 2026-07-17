class AppConstants {
  AppConstants._();

  // Supabase table name
  static const String energyLogsTable = 'energy_logs';

  // Local sembast store name
  static const String energyLogsStore = 'energy_logs';

  // Meter multiplying factor (CT/PT factor)
  static const double multiplyingFactor = 5.0;

  // Tariff per unit (₹)
  static const double tariffPerUnit = 8.68;

  // Contract demand in kVA
  static const double defaultContractDemandKva = 400.00;

  // PF penalty threshold
  static const double pfPenaltyThreshold = 0.95;

  // Thresholds
  static const double mdWarningThresholdKva = 380.00;
  static const double pfCriticalThreshold = 0.90;
}
