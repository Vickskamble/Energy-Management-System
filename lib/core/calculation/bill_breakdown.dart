class BillBreakdown {
  final double totalUnits;
  final double energyCharges;
  final double demandCharges;
  final double facCharges;
  final double wheelingCharges;
  final double electricityDuty;
  final double taxes;
  final double pfRebate;
  final double pfSurcharge;
  final double subsidy;
  final double todCharges;
  final double regionSubsidy;
  final double rebateSection106;
  final double fixedCharge;
  final double icrRebate;
  final double lfIncentive;
  final double ppdRebate;
  final double bulkRebate;
  final double arrearsDpc;
  final double roundingAdjustment;
  final double netBill;
  final Map<String, double> todZoneUnits;
  final Map<String, double> todZoneCharges;
  final double billingDemand;
  final double contractDemand;
  final double powerFactor;
  final double loadFactor;
  final double averageUnitCost;

  /// Payable in time (after PPD) — floored to the nearest ₹10 like the
  /// printed bill. 0 when the calculator did not produce one.
  final double payableEarly;

  /// Payable after the due-date (DPC paid) — floored to the nearest ₹10.
  final double payableAfterDpc;

  const BillBreakdown({
    required this.totalUnits,
    required this.energyCharges,
    required this.demandCharges,
    required this.facCharges,
    required this.wheelingCharges,
    required this.electricityDuty,
    required this.taxes,
    required this.pfRebate,
    required this.pfSurcharge,
    required this.subsidy,
    this.todCharges = 0,
    this.regionSubsidy = 0,
    this.rebateSection106 = 0,
    this.fixedCharge = 0,
    this.icrRebate = 0,
    this.lfIncentive = 0,
    this.ppdRebate = 0,
    this.bulkRebate = 0,
    this.arrearsDpc = 0,
    this.roundingAdjustment = 0,
    this.todZoneUnits = const {},
    this.todZoneCharges = const {},
    this.payableEarly = 0,
    this.payableAfterDpc = 0,
    required this.netBill,
    required this.billingDemand,
    required this.contractDemand,
    required this.powerFactor,
    required this.loadFactor,
    required this.averageUnitCost,
  });

  /// Floor `amount` down to the nearest ₹10 (MSEDCL payable columns).
  static double roundToTen(double amount) =>
      (amount / 10).floorToDouble() * 10;

  double get energyChargesPercent =>
      netBill > 0 ? (energyCharges / netBill * 100) : 0;
  double get demandChargesPercent =>
      netBill > 0 ? (demandCharges / netBill * 100) : 0;
  double get facPercent => netBill > 0 ? (facCharges / netBill * 100) : 0;
  double get wheelingPercent =>
      netBill > 0 ? (wheelingCharges / netBill * 100) : 0;
  double get taxesPercent => netBill > 0 ? (taxes / netBill * 100) : 0;
  double get dutyPercent => netBill > 0 ? (electricityDuty / netBill * 100) : 0;
  double get todPercent => netBill > 0 ? (todCharges / netBill * 100) : 0;

  Map<String, double> toCategoryMap() => {
    'Energy Charges': energyCharges,
    'Demand Charges': demandCharges,
    'FAC': facCharges,
    'Wheeling': wheelingCharges,
    'Electricity Duty': electricityDuty,
    'Taxes': taxes,
    if (todCharges != 0) 'TOD Charges': todCharges,
    if (fixedCharge != 0) 'Fixed Charge': fixedCharge,
    if (icrRebate != 0) 'ICR Rebate': -icrRebate,
    if (lfIncentive != 0) 'LF Incentive': -lfIncentive,
    if (ppdRebate != 0) 'PPD Rebate': -ppdRebate,
    if (bulkRebate != 0) 'Bulk Rebate': -bulkRebate,
    if (arrearsDpc != 0) 'Arrears/DPC': arrearsDpc,
    if (roundingAdjustment != 0) 'Rounding': roundingAdjustment,
  };

  Map<String, double> toPercentMap() => {
    'Energy': energyChargesPercent,
    'Demand': demandChargesPercent,
    'FAC': facPercent,
    'Wheeling': wheelingPercent,
    'Duty': dutyPercent,
    'Taxes': taxesPercent,
    if (todCharges != 0) 'TOD': todPercent,
  };
}

class MonthComparison {
  final BillBreakdown current;
  final BillBreakdown? previous;
  final double billDifference;
  final double billPercentChange;
  final double unitDifference;
  final double unitPercentChange;
  final double demandDifference;
  final double demandPercentChange;
  final double pfDifference;

  const MonthComparison({
    required this.current,
    this.previous,
    required this.billDifference,
    required this.billPercentChange,
    required this.unitDifference,
    required this.unitPercentChange,
    required this.demandDifference,
    required this.demandPercentChange,
    required this.pfDifference,
  });

  bool get isBillIncreased => billDifference > 0;
  bool get isBillDecreased => billDifference < 0;
  bool get isUnitIncreased => unitDifference > 0;
  bool get isDemandIncreased => demandDifference > 0;
  bool get isPfImproved => pfDifference > 0;
}

class BusinessKpi {
  final double billHealthScore;
  final double energyScore;

  const BusinessKpi({required this.billHealthScore, required this.energyScore});
}

class CalculationValidation {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> passed;

  const CalculationValidation({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.passed,
  });
}

class InsightItem {
  final String title;
  final String description;
  final String? recommendation;
  final InsightSeverity severity;

  const InsightItem({
    required this.title,
    required this.description,
    this.recommendation,
    required this.severity,
  });
}

enum InsightSeverity { positive, neutral, warning, critical }
