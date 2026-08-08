import '../../domain/entities/energy_log_entity.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'bill_breakdown.dart';
import 'energy_calculator.dart';

class BillCalculator {
  BillCalculator._();

  static BillBreakdown calculate({
    required List<EnergyLogEntity> logs,
    double? contractDemand,
    double? energyRate,
    double? demandRate,
    double? facRate,
    double? wheelingRate,
    double? electricityDutyPerUnit,
    double? taxPerUnit,
    List<double>? todMultipliers,
    double regionSubsidy = 0,
    double rebateSection106 = 0,
    List<EnergyLogEntity>? ratchetLogs,
    double ratchetFloorPercent = AppConstants.billingDemandFloorPercent,
    int ratchetMonths = AppConstants.ratchetWindowMonths,
    List<double> manualRatchetDemandKva = const [],
  }) {
    final effectiveContractDemand = contractDemand ?? AppConfig.contractDemandKva;
    final effectiveEnergyRate = energyRate ?? AppConfig.tariffPerUnit;
    final effectiveDemandRate = demandRate ?? AppConfig.demandChargePerKva;
    final effectiveFacRate = facRate ?? AppConfig.facRatePerUnit;
    final effectiveWheelingRate = wheelingRate ?? AppConfig.wheelingChargePerUnit;
    final effectiveEdRate = electricityDutyPerUnit ?? AppConfig.electricityDutyPerUnit;
    final effectiveTaxRate = taxPerUnit ?? AppConfig.taxPerUnit;
    final effectiveTod = todMultipliers ?? AppConfig.todMultipliers;
    if (logs.isEmpty) return _emptyBreakdown(effectiveContractDemand);

    double totalKwh = 0;
    double totalKvah = 0;
    double peakMd = 0;
    double sumMd = 0;
    int mdCount = 0;

    for (final log in logs) {
      totalKwh += log.kwh;
      totalKvah += log.kvah;
      final actualMd = log.mdRecorded * log.multiplyingFactor;
      if (actualMd > peakMd) peakMd = actualMd;
      sumMd += actualMd;
      mdCount++;
    }

    final powerFactor = totalKvah > 0
        ? EnergyCalculator.calculatePowerFactor(totalKwh, totalKvah)
        : 0.0;
    // Billing units are measured from the kVAh (apparent) energy — the
    // meter reads cumulative kWh/kVAh, each reading's own multiplying factor
    // (CT × PT ratio) is applied so meters with different MF never distort
    // the bill. Always billed on kVAh.
    double totalUnits = 0;
    for (final log in logs) {
      totalUnits += log.kvah * log.multiplyingFactor;
    }
    final billingDemand = EnergyCalculator.calculateBillingDemand(
      peakMd,
      effectiveContractDemand,
      ratchetFloorPercent: ratchetFloorPercent,
      ratchetPeak: _ratchetPeak(logs, ratchetLogs, ratchetMonths,
          manualRatchetDemandKva: manualRatchetDemandKva),
    );
    final avgDemand = mdCount > 0 ? sumMd / mdCount.toDouble() : 0.0;
    final loadFactor = EnergyCalculator.calculateLoadFactor(avgDemand, peakMd);

    final energyCharges = EnergyCalculator.calculateEnergyCharges(
      totalUnits,
      effectiveEnergyRate,
    );
    final demandCharges = EnergyCalculator.calculateDemandCharges(
      billingDemand,
      effectiveDemandRate,
    );
    final facCharges = EnergyCalculator.calculateFac(
      totalUnits,
      effectiveFacRate,
    );
    final wheelingCharges = EnergyCalculator.calculateWheelingCharges(
      totalUnits,
      effectiveWheelingRate,
    );

    // TOD charges
    final todCharges = EnergyCalculator.calculateTodCharges(
      energyCharges,
      effectiveTod,
    );

    // Electricity duty = per-unit × total units (NOT percentage)
    final electricityDuty = EnergyCalculator.calculateElectricityDuty(
      totalUnits,
      effectiveEdRate,
    );

    // Taxes = per-unit × total units (NOT percentage)
    final taxes = EnergyCalculator.calculateTaxes(
      totalUnits,
      effectiveTaxRate,
    );

    final pfRebate = EnergyCalculator.calculatePfRebate(
      energyCharges,
      demandCharges,
      powerFactor,
    );
    final pfSurcharge = EnergyCalculator.calculatePfSurcharge(
      energyCharges,
      demandCharges,
      powerFactor,
    );
    final subsidy = AppConfig.subsidyPercent > 0
        ? (energyCharges + demandCharges + facCharges + wheelingCharges + todCharges) *
            AppConfig.subsidyPercent /
            100
        : 0.0;

    final netBill = EnergyCalculator.calculateTotalBill(
      energyCharges: energyCharges,
      demandCharges: demandCharges,
      facCharges: facCharges,
      wheelingCharges: wheelingCharges,
      electricityDuty: electricityDuty,
      taxes: taxes,
      pfRebate: pfRebate,
      pfSurcharge: pfSurcharge,
      subsidy: subsidy,
      todCharges: todCharges,
      regionSubsidy: regionSubsidy,
      rebateSection106: rebateSection106,
    );

    final averageUnitCost = EnergyCalculator.calculateAverageUnitCost(
      netBill,
      totalUnits,
    );

    return BillBreakdown(
      totalUnits: totalUnits,
      energyCharges: (energyCharges * 100).roundToDouble() / 100,
      demandCharges: (demandCharges * 100).roundToDouble() / 100,
      facCharges: (facCharges * 100).roundToDouble() / 100,
      wheelingCharges: (wheelingCharges * 100).roundToDouble() / 100,
      electricityDuty: (electricityDuty * 100).roundToDouble() / 100,
      taxes: (taxes * 100).roundToDouble() / 100,
      pfRebate: (pfRebate * 100).roundToDouble() / 100,
      pfSurcharge: (pfSurcharge * 100).roundToDouble() / 100,
      subsidy: (subsidy * 100).roundToDouble() / 100,
      todCharges: (todCharges * 100).roundToDouble() / 100,
      regionSubsidy: (regionSubsidy * 100).roundToDouble() / 100,
      rebateSection106: (rebateSection106 * 100).roundToDouble() / 100,
      netBill: (netBill * 100).roundToDouble() / 100,
      billingDemand: (billingDemand * 100).roundToDouble() / 100,
      contractDemand: effectiveContractDemand,
      powerFactor: (powerFactor * 1000).roundToDouble() / 1000,
      loadFactor: (loadFactor * 1000).roundToDouble() / 1000,
      averageUnitCost: (averageUnitCost * 100).roundToDouble() / 100,
    );
  }

  static MonthComparison compare(
    BillBreakdown current,
    BillBreakdown? previous,
  ) {
    if (previous == null) {
      return MonthComparison(
        current: current,
        billDifference: 0,
        billPercentChange: 0,
        unitDifference: 0,
        unitPercentChange: 0,
        demandDifference: 0,
        demandPercentChange: 0,
        pfDifference: 0,
      );
    }
    return MonthComparison(
      current: current,
      previous: previous,
      billDifference:
          (EnergyCalculator.calculateDifference(
                    current.netBill,
                    previous.netBill,
                  ) *
                  100)
              .roundToDouble() /
          100,
      billPercentChange:
          (EnergyCalculator.calculatePercentChange(
                    current.netBill,
                    previous.netBill,
                  ) *
                  100)
              .roundToDouble() /
          100,
      unitDifference:
          (EnergyCalculator.calculateDifference(
                    current.totalUnits,
                    previous.totalUnits,
                  ) *
                  100)
              .roundToDouble() /
          100,
      unitPercentChange:
          (EnergyCalculator.calculatePercentChange(
                    current.totalUnits,
                    previous.totalUnits,
                  ) *
                  100)
              .roundToDouble() /
          100,
      demandDifference:
          (EnergyCalculator.calculateDifference(
                    current.billingDemand,
                    previous.billingDemand,
                  ) *
                  100)
              .roundToDouble() /
          100,
      demandPercentChange:
          (EnergyCalculator.calculatePercentChange(
                    current.billingDemand,
                    previous.billingDemand,
                  ) *
                  100)
              .roundToDouble() /
          100,
      pfDifference:
          (EnergyCalculator.calculateDifference(
                    current.powerFactor,
                    previous.powerFactor,
                  ) *
                  1000)
              .roundToDouble() /
          1000,
    );
  }

  static BusinessKpi calculateKpis(BillBreakdown breakdown) {
    return BusinessKpi(
      billHealthScore:
          (EnergyCalculator.calculateBillHealthScore(
                    powerFactor: breakdown.powerFactor,
                    loadFactor: breakdown.loadFactor,
                    billingDemand: breakdown.billingDemand,
                    contractDemand: breakdown.contractDemand,
                    pfSurcharge: breakdown.pfSurcharge,
                  ) *
                  100)
              .roundToDouble() /
          100,
      energyScore:
          (EnergyCalculator.calculateEnergyScore(
                    powerFactor: breakdown.powerFactor,
                    loadFactor: breakdown.loadFactor,
                    averageUnitCost: breakdown.averageUnitCost,
                  ) *
                  100)
              .roundToDouble() /
          100,
    );
  }

  /// Ratchet peak — the highest demand considered in the billing demand of
  /// the current month. Two sources are combined:
  ///  1. The highest monthly demand (actual kVA = MD × MF) over the trailing
  ///     window [latest month of [logs] − [ratchetMonths] months .. latest
  ///     month] computed from the full history ([ratchetLogs]) — once a peak
  ///     occurs it stays in the billing demand of every following month until
  ///     a higher one breaks it or it leaves the window.
  ///  2. User-provided preceding-11-month demands ([manualRatchetDemandKva])
  ///     entered in Settings → Billing so bills match the discom's own
  ///     ratchet even before the app has 11 months of history.
  static double _ratchetPeak(
    List<EnergyLogEntity> logs,
    List<EnergyLogEntity>? ratchetLogs,
    int ratchetMonths, {
    List<double> manualRatchetDemandKva = const [],
  }) {
    final manualPeak = manualRatchetDemandKva.fold(
      0.0,
      (peak, v) => v > peak ? v : peak,
    );
    if (ratchetLogs == null || ratchetLogs.isEmpty || ratchetMonths < 1) {
      return manualPeak;
    }
    DateTime? latestMonth;
    for (final log in logs) {
      final m = DateTime(log.loggedAt.year, log.loggedAt.month);
      if (latestMonth == null || m.isAfter(latestMonth)) latestMonth = m;
    }
    if (latestMonth == null) return 0;

    final windowStart = DateTime(
      latestMonth.year,
      latestMonth.month - ratchetMonths,
      1,
    );
    final windowEnd = DateTime(latestMonth.year, latestMonth.month + 1, 1);
    final monthlyMax = <int, double>{};
    for (final log in ratchetLogs) {
      if (log.loggedAt.isBefore(windowStart) ||
          !log.loggedAt.isBefore(windowEnd)) {
        continue;
      }
      final key = log.loggedAt.year * 12 + (log.loggedAt.month - 1);
      final actualMd = log.mdRecorded * log.multiplyingFactor;
      monthlyMax.update(
        key,
        (v) => actualMd > v ? actualMd : v,
        ifAbsent: () => actualMd,
      );
    }
    var ratchetPeak = 0.0;
    for (final v in monthlyMax.values) {
      if (v > ratchetPeak) ratchetPeak = v;
    }
    if (manualPeak > ratchetPeak) ratchetPeak = manualPeak;
    return ratchetPeak;
  }

  static BillBreakdown _emptyBreakdown(double contractDemand) {    return BillBreakdown(
      totalUnits: 0,
      energyCharges: 0,
      demandCharges: 0,
      facCharges: 0,
      wheelingCharges: 0,
      electricityDuty: 0,
      taxes: 0,
      pfRebate: 0,
      pfSurcharge: 0,
      subsidy: 0,
      todCharges: 0,
      regionSubsidy: 0,
      rebateSection106: 0,
      netBill: 0,
      billingDemand: 0,
      contractDemand: contractDemand,
      powerFactor: 0,
      loadFactor: 0,
      averageUnitCost: 0,
    );
  }
}
