import '../../domain/entities/energy_log_entity.dart';
import '../config/app_config.dart';
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
    List<EnergyLogEntity>? ratchetLogs,
  }) {
    final now = referenceDate ?? DateTime.now();
    if (monthLogs.isEmpty) return null;

    final monthBreakdown = BillCalculator.calculate(
      logs: monthLogs,
      ratchetLogs: ratchetLogs,
    );
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day.clamp(1, daysInMonth);
    final scale = daysInMonth / daysElapsed.toDouble();

    final projectedUnits = monthBreakdown.totalUnits * scale;
    final energyCharges =
        projectedUnits * AppConfig.tariffPerUnit;
    final facCharges = projectedUnits * AppConfig.facRatePerUnit;
    final wheelingCharges =
        projectedUnits * AppConfig.wheelingChargePerUnit;
    final demandCharges =
        monthBreakdown.billingDemand * AppConfig.demandChargePerKva;

    // Electricity duty = % of energy charges (official model, HT exempt);
    // flat per-unit × units only as legacy fallback.
    final duty = AppConfig.dutyPercent > 0
        ? energyCharges * AppConfig.dutyPercent / 100
        : EnergyCalculator.calculateElectricityDuty(
            projectedUnits,
            AppConfig.electricityDutyPerUnit,
          );
    // Taxes = per-unit × projected units (NOT percentage)
    final taxes = EnergyCalculator.calculateTaxes(
      projectedUnits,
      AppConfig.taxPerUnit,
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
    final subsidy = AppConfig.subsidyPercent > 0
        ? (energyCharges + demandCharges + facCharges + wheelingCharges) *
            AppConfig.subsidyPercent /
            100
        : 0.0;
    final projectedBill =
        energyCharges +
        demandCharges +
        facCharges +
        wheelingCharges +
        duty +
        taxes +
        surcharge +
        AppConfig.fixedCharge -
        rebate -
        subsidy;

    return BillForecast(
      projectedBill: projectedBill,
      projectedUnits: projectedUnits,
      dailyAverageBill: monthBreakdown.netBill / daysElapsed,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }
}
