import '../../domain/entities/energy_log_entity.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'bill_breakdown.dart';
import 'energy_calculator.dart';

class BillCalculator {
  BillCalculator._();

  static BillBreakdown calculate({
    required List<EnergyLogEntity> logs,
    double contractDemand = AppConstants.defaultContractDemandKva,
    double? energyRate,
    double demandRate = AppConstants.demandChargePerKva,
    double facRate = AppConstants.facRatePerUnit,
    double wheelingRate = AppConstants.wheelingChargePerUnit,
  }) {
    final effectiveEnergyRate = energyRate ?? AppConfig.tariffPerUnit;
    if (logs.isEmpty) return _emptyBreakdown(contractDemand);

    double totalKwh = 0;
    double totalKvah = 0;
    double peakMd = 0;
    double sumMd = 0;
    int mdCount = 0;

    for (final log in logs) {
      totalKwh += log.kwh;
      totalKvah += log.kvah;
      if (log.mdRecorded > peakMd) peakMd = log.mdRecorded;
      sumMd += log.mdRecorded;
      mdCount++;
    }

    final powerFactor = totalKvah > 0
        ? EnergyCalculator.calculatePowerFactor(totalKwh, totalKvah)
        : 0.0;
    final totalUnits = totalKwh * AppConstants.multiplyingFactor;
    final billingDemand = EnergyCalculator.calculateBillingDemand(
      peakMd,
      contractDemand,
    );
    final avgDemand = mdCount > 0 ? sumMd / mdCount.toDouble() : 0.0;
    final loadFactor = EnergyCalculator.calculateLoadFactor(avgDemand, peakMd);

    final energyCharges = EnergyCalculator.calculateEnergyCharges(
      totalUnits,
      effectiveEnergyRate,
    );
    final demandCharges = EnergyCalculator.calculateDemandCharges(
      billingDemand,
      demandRate,
    );
    final facCharges = EnergyCalculator.calculateFac(totalUnits, facRate);
    final wheelingCharges = EnergyCalculator.calculateWheelingCharges(
      totalUnits,
      wheelingRate,
    );

    final subtotal =
        energyCharges + demandCharges + facCharges + wheelingCharges;
    final electricityDuty = EnergyCalculator.calculateElectricityDuty(
      subtotal,
      AppConstants.electricityDutyPercent,
    );
    final taxes = EnergyCalculator.calculateTaxes(
      subtotal + electricityDuty,
      AppConstants.taxPercent,
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
    final subsidy = AppConstants.subsidyPercent > 0
        ? subtotal * AppConstants.subsidyPercent / 100
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
      netBill: (netBill * 100).roundToDouble() / 100,
      billingDemand: (billingDemand * 100).roundToDouble() / 100,
      contractDemand: contractDemand,
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

  static BillBreakdown _emptyBreakdown(double contractDemand) {
    return BillBreakdown(
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
      netBill: 0,
      billingDemand: 0,
      contractDemand: contractDemand,
      powerFactor: 0,
      loadFactor: 0,
      averageUnitCost: 0,
    );
  }
}
