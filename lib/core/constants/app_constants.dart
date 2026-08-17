class AppConstants {
  AppConstants._();

  static const String energyLogsTable = 'energy_logs';
  static const String energyLogsStore = 'energy_logs';

  static const double multiplyingFactor = 5.0;
  static const double tariffPerUnit = 8.44;
  static const double defaultContractDemandKva = 201.00;
  static const double pfPenaltyThreshold = 0.95;
  static const double mdWarningThresholdKva = 190.00;
  static const double mdWarningRatio = 0.9;
  static const double pfCriticalThreshold = 0.90;

  /// Billing demand floor — always at least this % of contract demand.
  static const double billingDemandFloorPercent = 0.75;

  /// Ratchet window — the highest monthly demand of the preceding N months
  /// is always considered in the billing demand of the current month.
  static const int ratchetWindowMonths = 11;

  static const double demandChargePerKva = 650.00;
  static const double facRatePerUnit = 0.30;
  static const double wheelingChargePerUnit = 0.81;
  static const double electricityDutyPerUnit = 0.275;
  static const double taxPerUnit = 0.279;
  static const double pfRebatePercent = 1.0;
  static const double pfSurchargePercent = 5.0;
  static const double subsidyPercent = 0.0;
  static const double pfRebateThreshold = 0.95;
  static const double pfSurchargeThreshold = 0.90;
  static const double loadFactorThresholdGood = 0.75;

  /// Fraction of the daily kWh target at which a "near target" alert fires.
  static const double dailyKwhWarningRatio = 0.9;

  /// Tolerance (%) for actual vs estimated bill reconciliation (Issue 7B).
  static const double billAccuracyTolerancePercent = 10.0;

  /// Tax as % of energy charges (official ~1.25%; used instead of the flat
  /// per-unit [taxPerUnit] whenever > 0).
  static const double taxPercent = 1.25;

  /// Incremental Consumption Rebate (ICR) — ₹ per unit on the incremental
  /// consumption when it grows ≥ 10% vs the same month last year.
  static const double icrRatePerUnit = 0.75;

  /// Load Factor incentive — % of (energy + demand) charges.
  static const double lfIncentivePercent = 0.0;

  /// Prompt Payment Discount — % of the bill (energy + demand + FAC +
  /// wheeling + TOD + duty + taxes) when paid on time.
  static const double ppdPercent = 2.0;

  /// Bulk consumption rebate — % of energy charges.
  static const double bulkRebatePercent = 0.0;

  /// Arrears / DPC flat amount in ₹ (added to the bill).
  static const double arrearsDpcAmount = 0.0;

  /// Round the final bill to the nearest ₹10 (MSEDCL practice).
  static const bool roundToTen = true;

  /// Bill on kVAh (apparent energy, PF-adjusted — official). When off the
  /// kWh (active energy) is used as the billing unit.
  static const bool billOnKvah = true;
}
