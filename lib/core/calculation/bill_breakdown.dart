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
  final double netBill;
  final double billingDemand;
  final double contractDemand;
  final double powerFactor;
  final double loadFactor;
  final double averageUnitCost;

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
    required this.netBill,
    required this.billingDemand,
    required this.contractDemand,
    required this.powerFactor,
    required this.loadFactor,
    required this.averageUnitCost,
  });

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
