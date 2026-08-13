import '../../domain/entities/energy_log_entity.dart';
import '../config/app_config.dart';
import '../config/tariff_presets.dart';
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
    double? dutyPercent,
    double? taxPercent,
    double? icrRate,
    double? icrLastYearUnits,
    double? lfIncentivePercent,
    double? ppdPercent,
    double? bulkRebatePercent,
    double? arrearsDpcAmount,
    bool? roundToTen,
    bool? billOnKvah,
    List<EnergySlab>? slabs,
    double fixedCharge = 0,
    List<double>? todMultipliers,
    double regionSubsidy = 0,
    double rebateSection106 = 0,
    List<EnergyLogEntity>? ratchetLogs,
    int ratchetMonths = AppConstants.ratchetWindowMonths,
    List<double>? manualRatchetDemandKva,
  }) {
    final effectiveContractDemand = contractDemand ?? AppConfig.contractDemandKva;
    final effectiveEnergyRate = energyRate ?? AppConfig.tariffPerUnit;
    final effectiveDemandRate = demandRate ?? AppConfig.demandChargePerKva;
    final effectiveFacRate = facRate ?? AppConfig.facRatePerUnit;
    final effectiveWheelingRate = wheelingRate ?? AppConfig.wheelingChargePerUnit;
    final effectiveEdRate = electricityDutyPerUnit ?? AppConfig.electricityDutyPerUnit;
    final effectiveTaxRate = taxPerUnit ?? AppConfig.taxPerUnit;
    final effectiveDutyPercent = dutyPercent ?? AppConfig.dutyPercent;
    final effectiveTaxPercent = taxPercent ?? AppConfig.taxPercent;
    final effectiveIcrRate = icrRate ?? AppConfig.icrRatePerUnit;
    final effectiveIcrLastYear = icrLastYearUnits ?? AppConfig.icrLastYearUnits;
    final effectiveLfPercent = lfIncentivePercent ?? AppConfig.lfIncentivePercent;
    final effectivePpdPercent = ppdPercent ?? AppConfig.ppdPercent;
    final effectiveBulkPercent =
        bulkRebatePercent ?? AppConfig.bulkRebatePercent;
    final effectiveArrears = arrearsDpcAmount ?? AppConfig.arrearsDpcAmount;
    final effectiveRoundToTen = roundToTen ?? AppConfig.roundToTen;
    final effectiveBillOnKvah = billOnKvah ?? AppConfig.billOnKvah;
    final effectiveSlabs = slabs ?? AppConfig.energySlabs;
    final effectiveFixedCharge =
        fixedCharge > 0 ? fixedCharge : AppConfig.fixedCharge;
    final effectiveTod = todMultipliers ?? AppConfig.todMultipliers;
    if (logs.isEmpty) return _emptyBreakdown(effectiveContractDemand);

    double totalKwh = 0;
    double totalKvah = 0;
    double peakMd = 0;
    double sumMd = 0;
    int mdCount = 0;

    for (final log in logs) {
      // Applying each meter's CT/PT ratio keeps the combined PF correct when
      // multiple meters with different multipliers are billed together.
      totalKwh += log.kwh * log.multiplyingFactor;
      totalKvah += log.kvah * log.multiplyingFactor;
      final actualMd = log.mdRecorded * log.multiplyingFactor;
      if (actualMd > peakMd) peakMd = actualMd;
      sumMd += actualMd;
      mdCount++;
    }

    // PF = billed kWh ÷ billed kVAh. When no kVAh data exists (e.g. Excel
    // imports without that column), fall back to the kWh-weighted average of
    // the per-reading power factors stored by the user — never report a
    // false 0.000 penalty.
    double powerFactor = 0;
    if (totalKvah > 0) {
      powerFactor = EnergyCalculator.calculatePowerFactor(
        totalKwh,
        totalKvah,
      );
    } else {
      double pfSum = 0;
      double energySum = 0;
      for (final log in logs) {
        if (log.powerFactor > 0) {
          pfSum += log.powerFactor * log.kwh * log.multiplyingFactor;
          energySum += log.kwh * log.multiplyingFactor;
        }
      }
      if (energySum > 0) powerFactor = pfSum / energySum;
    }
    // Billing units: official kVAh (apparent energy, PF-adjusted) or kWh
    // when the user switches the toggle off. Each reading's own multiplying
    // factor (CT × PT ratio) is applied so meters with different MF never
    // distort the bill.
    double totalUnits = 0;
    for (final log in logs) {
      totalUnits +=
          (effectiveBillOnKvah ? log.kvah : log.kwh) * log.multiplyingFactor;
    }
    final billingDemand = EnergyCalculator.calculateBillingDemand(
      peakMd,
      effectiveContractDemand,
      ratchetPeak: _ratchetPeak(logs, ratchetLogs, ratchetMonths,
          manualRatchetDemandKva:
              manualRatchetDemandKva ?? AppConfig.precedingDemandKva),
    );
    final avgDemand = mdCount > 0 ? sumMd / mdCount.toDouble() : 0.0;
    final loadFactor = EnergyCalculator.calculateLoadFactor(avgDemand, peakMd);

    final energyCharges = effectiveSlabs.isNotEmpty
        ? EnergyCalculator.calculateSlabEnergy(totalUnits, effectiveSlabs)
        : EnergyCalculator.calculateEnergyCharges(
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

    // Electricity duty = % of energy charges (official model, HT exempt);
    // flat per-unit × units only as legacy fallback.
    final electricityDuty = effectiveDutyPercent > 0
        ? energyCharges * effectiveDutyPercent / 100
        : EnergyCalculator.calculateElectricityDuty(
            totalUnits,
            effectiveEdRate,
          );

    // Taxes = % of energy charges (official ~1.25%); flat per-unit × units
    // only as legacy fallback.
    final taxes = effectiveTaxPercent > 0
        ? energyCharges * effectiveTaxPercent / 100
        : EnergyCalculator.calculateTaxes(
            totalUnits,
            effectiveTaxRate,
          );

    // Incremental Consumption Rebate — ₹ per unit on the incremental
    // consumption when it grows ≥ 10% vs the same month last year.
    final icrRebate = effectiveIcrRate > 0 &&
            effectiveIcrLastYear > 0 &&
            totalUnits >= effectiveIcrLastYear * 1.10
        ? (totalUnits - effectiveIcrLastYear) * effectiveIcrRate
        : 0.0;

    // Load Factor incentive — % of (energy + demand) charges.
    final lfIncentive = effectiveLfPercent > 0
        ? (energyCharges + demandCharges) * effectiveLfPercent / 100
        : 0.0;

    // Bulk consumption rebate — % of energy charges.
    final bulkRebate = effectiveBulkPercent > 0
        ? energyCharges * effectiveBulkPercent / 100
        : 0.0;

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

    // Prompt Payment Discount — % of the bill after other rebates.
    final ppdRebate = effectivePpdPercent > 0
        ? (energyCharges +
              demandCharges +
              facCharges +
              wheelingCharges +
              todCharges +
              effectiveFixedCharge +
              electricityDuty +
              taxes -
              pfRebate -
              icrRebate -
              lfIncentive -
              bulkRebate -
              subsidy -
              regionSubsidy -
              rebateSection106) *
            effectivePpdPercent /
            100
        : 0.0;

    final rawNet = EnergyCalculator.calculateTotalBill(
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
      fixedCharge: effectiveFixedCharge,
      icrRebate: icrRebate,
      lfIncentive: lfIncentive,
      ppdRebate: ppdRebate,
      bulkRebate: bulkRebate,
      arrearsDpc: effectiveArrears,
    );

    // Round the final bill to the nearest ₹10 (MSEDCL practice).
    final roundingAdjustment = effectiveRoundToTen
        ? (rawNet / 10).roundToDouble() * 10 - rawNet
        : 0.0;
    final netBill = rawNet + roundingAdjustment;

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
      fixedCharge: (effectiveFixedCharge * 100).roundToDouble() / 100,
      icrRebate: (icrRebate * 100).roundToDouble() / 100,
      lfIncentive: (lfIncentive * 100).roundToDouble() / 100,
      ppdRebate: (ppdRebate * 100).roundToDouble() / 100,
      bulkRebate: (bulkRebate * 100).roundToDouble() / 100,
      arrearsDpc: (effectiveArrears * 100).roundToDouble() / 100,
      roundingAdjustment:
          (roundingAdjustment * 100).roundToDouble() / 100,
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
    List<double>? manualRatchetDemandKva,
  }) {
    final effectiveManual =
        manualRatchetDemandKva ?? AppConfig.precedingDemandKva;
    final manualPeak = effectiveManual.fold(
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
      fixedCharge: 0,
      icrRebate: 0,
      lfIncentive: 0,
      ppdRebate: 0,
      bulkRebate: 0,
      arrearsDpc: 0,
      roundingAdjustment: 0,
      netBill: 0,
      billingDemand: 0,
      contractDemand: contractDemand,
      powerFactor: 0,
      loadFactor: 0,
      averageUnitCost: 0,
    );
  }
}
