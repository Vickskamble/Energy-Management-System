import '../../domain/entities/energy_log_entity.dart';
import '../constants/app_constants.dart';
import 'bill_calculator.dart';
import 'energy_calculator.dart';

class BillForecast {
  final double projectedBill;
  final double projectedUnits;
  final double dailyAverageBill;
  final int daysElapsed;
  final int daysInMonth;

  const BillForecast({
    required this.projectedBill,
    required this.projectedUnits,
    required this.dailyAverageBill,
    required this.daysElapsed,
    required this.daysInMonth,
  });
}

class BillForecastCalculator {
  BillForecastCalculator._();

  static BillForecast? calculate({
    required List<EnergyLogEntity> monthLogs,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    if (monthLogs.isEmpty) return null;

    final monthBreakdown = BillCalculator.calculate(logs: monthLogs);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day.clamp(1, daysInMonth);
    final scale = daysInMonth / daysElapsed.toDouble();

    final projectedUnits = monthBreakdown.totalUnits * scale;
    final energyCharges = projectedUnits * AppConstants.tariffPerUnit;
    final facCharges = projectedUnits * AppConstants.facRatePerUnit;
    final wheelingCharges = projectedUnits * AppConstants.wheelingChargePerUnit;
    final demandCharges =
        monthBreakdown.billingDemand * AppConstants.demandChargePerKva;
    final subtotal =
        energyCharges + demandCharges + facCharges + wheelingCharges;
    final duty = EnergyCalculator.calculateElectricityDuty(
      subtotal,
      AppConstants.electricityDutyPercent,
    );
    final taxes = EnergyCalculator.calculateTaxes(
      subtotal + duty,
      AppConstants.taxPercent,
    );
    final rebate = EnergyCalculator.calculatePfRebate(
      energyCharges,
      demandCharges,
      monthBreakdown.powerFactor,
    );
    final surcharge = EnergyCalculator.calculatePfSurcharge(
      energyCharges,
      demandCharges,
      monthBreakdown.powerFactor,
    );
    final subsidy = AppConstants.subsidyPercent > 0
        ? subtotal * AppConstants.subsidyPercent / 100
        : 0.0;
    final projectedBill =
        subtotal + duty + taxes + surcharge - rebate - subsidy;

    return BillForecast(
      projectedBill: projectedBill,
      projectedUnits: projectedUnits,
      dailyAverageBill: monthBreakdown.netBill / daysElapsed,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }
}
