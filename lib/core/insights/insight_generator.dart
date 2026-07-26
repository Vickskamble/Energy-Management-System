import '../constants/app_constants.dart';
import '../calculation/bill_breakdown.dart';
import '../../domain/entities/energy_log_entity.dart';

class InsightGenerator {
  InsightGenerator._();

  static List<InsightItem> generate({
    required BillBreakdown breakdown,
    required MonthComparison? comparison,
    required BusinessKpi kpis,
    required List<EnergyLogEntity> logs,
  }) {
    final insights = <InsightItem>[];
    insights.addAll(_billInsights(breakdown, comparison));
    insights.addAll(_pfInsights(breakdown));
    insights.addAll(_demandInsights(breakdown, comparison));
    insights.addAll(_efficiencyInsights(breakdown, kpis));
    insights.addAll(_costInsights(breakdown, comparison));
    insights.addAll(_currentUnbalanceInsights(logs));
    return insights;
  }

  static List<InsightItem> _billInsights(BillBreakdown breakdown, MonthComparison? comparison) {
    final items = <InsightItem>[];

    final energyPct = breakdown.energyChargesPercent;

    items.add(InsightItem(
      title: 'Energy Charges are ${energyPct.toStringAsFixed(0)}% of Bill',
      description: energyPct > 60
          ? 'Energy charges dominate your bill. Consider energy efficiency measures to reduce consumption.'
          : energyPct > 40
              ? 'Energy charges are the largest bill component. Monitor usage patterns.'
              : 'Energy charges are well-controlled at $energyPct% of total bill.',
      severity: energyPct > 60 ? InsightSeverity.warning : InsightSeverity.neutral,
      recommendation: energyPct > 60
              ? 'Reduce energy consumption during peak hours. Consider VFDs on motors and LED lighting.'
              : null,
    ));

    if (comparison != null && comparison.previous != null) {
      items.add(InsightItem(
        title: 'Bill ${comparison.isBillIncreased ? 'Increased' : 'Decreased'} by ₹${comparison.billDifference.abs().toStringAsFixed(0)}',
        description: comparison.isBillIncreased
            ? 'Your bill rose by ${comparison.billPercentChange.toStringAsFixed(1)}% compared to last period.'
            : 'Your bill dropped by ${comparison.billPercentChange.abs().toStringAsFixed(1)}% — positive trend.',
        severity: comparison.isBillIncreased
            ? (comparison.billPercentChange > 20 ? InsightSeverity.critical : InsightSeverity.warning)
            : InsightSeverity.positive,
      ));
    }

    if (breakdown.averageUnitCost > 0) {
      items.add(InsightItem(
        title: 'Average Unit Cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}/kWh',
        description: breakdown.averageUnitCost > 10
            ? 'Your average unit cost is high. Review tariff category or consider open access if feasible.'
            : breakdown.averageUnitCost > 7
                ? 'Average unit cost is within typical commercial range.'
                : 'Your unit cost is competitive. Good tariff management.',
        severity: breakdown.averageUnitCost > 10 ? InsightSeverity.warning : InsightSeverity.positive,
      ));
    }

    return items;
  }

  static List<InsightItem> _pfInsights(BillBreakdown breakdown) {
    final items = <InsightItem>[];

    if (breakdown.powerFactor >= AppConstants.pfRebateThreshold) {
      items.add(InsightItem(
        title: 'Power Factor: ${breakdown.powerFactor.toStringAsFixed(3)}',
        description: 'Excellent! PF is above ${AppConstants.pfRebateThreshold}. You qualify for ${AppConstants.pfRebatePercent}% rebate of ₹${breakdown.pfRebate.toStringAsFixed(0)}.',
        severity: InsightSeverity.positive,
        recommendation: 'Maintain capacitor banks. PF above ${AppConstants.pfRebateThreshold} saves ₹${breakdown.pfRebate.toStringAsFixed(0)}/month.',
      ));
    } else if (breakdown.powerFactor >= AppConstants.pfSurchargeThreshold) {
      final canSave = breakdown.energyCharges * AppConstants.pfRebatePercent / 100;
      items.add(InsightItem(
        title: 'PF: ${breakdown.powerFactor.toStringAsFixed(3)} — Close to Rebate Threshold',
        description: 'PF is ${((AppConstants.pfRebateThreshold - breakdown.powerFactor) * 100).toStringAsFixed(1)}% away from ${AppConstants.pfRebateThreshold} rebate target. Improving PF can save ₹${canSave.toStringAsFixed(0)}/month.',
        severity: InsightSeverity.warning,
        recommendation: 'Check APFC panel settings. Adding ${((1 / breakdown.powerFactor - 1 / AppConstants.pfRebateThreshold) * breakdown.billingDemand).toStringAsFixed(0)} kVAr of capacitors can achieve rebate.',
      ));
    } else {
      items.add(InsightItem(
        title: 'PF: ${breakdown.powerFactor.toStringAsFixed(3)} — PF Penalty Applied',
        description: 'PF is below ${AppConstants.pfSurchargeThreshold}. A ${AppConstants.pfSurchargePercent}% surcharge of ₹${breakdown.pfSurcharge.toStringAsFixed(0)} applied. PF improvement is essential.',
        severity: InsightSeverity.critical,
        recommendation: 'Immediate capacitor bank maintenance required. Target PF > ${AppConstants.pfRebateThreshold} to avoid penalty and earn rebate.',
      ));
    }

    return items;
  }

  static List<InsightItem> _demandInsights(BillBreakdown breakdown, MonthComparison? comparison) {
    final items = <InsightItem>[];

    final demandUtilization = breakdown.contractDemand > 0
        ? (breakdown.billingDemand / breakdown.contractDemand * 100)
        : 0.0;

    if (demandUtilization > 90) {
      items.add(InsightItem(
        title: 'Demand at ${demandUtilization.toStringAsFixed(0)}% of Contract',
        description: 'Your billing demand (${breakdown.billingDemand.toStringAsFixed(1)} kVA) is very close to contract demand (${breakdown.contractDemand.toStringAsFixed(1)} kVA). Risk of excess demand penalty.',
        severity: InsightSeverity.critical,
        recommendation: 'Shift heavy loads to off-peak hours. Consider increasing contract demand if peak loads are unavoidable.',
      ));
    } else if (demandUtilization > 75) {
      items.add(InsightItem(
        title: 'Demand at ${demandUtilization.toStringAsFixed(0)}% of Contract',
        description: 'Healthy utilization. Your billing demand (${breakdown.billingDemand.toStringAsFixed(1)} kVA) vs contract (${breakdown.contractDemand.toStringAsFixed(1)} kVA).',
        severity: InsightSeverity.neutral,
      ));
    } else if (demandUtilization > 0) {
      items.add(InsightItem(
        title: 'Demand at ${demandUtilization.toStringAsFixed(0)}% of Contract',
        description: 'Low demand utilization. You may be paying for more capacity than needed.',
        severity: InsightSeverity.warning,
        recommendation: 'Review if contract demand can be reduced from ${breakdown.contractDemand.toStringAsFixed(0)} kVA to ${(breakdown.billingDemand * 1.2).toStringAsFixed(0)} kVA to save on demand charges.',
      ));
    }

    if (comparison != null && comparison.previous != null) {
      if (comparison.isDemandIncreased) {
        items.add(InsightItem(
          title: 'Demand ${comparison.demandPercentChange > 10 ? 'Spiked' : 'Increased'} by ${comparison.demandPercentChange.toStringAsFixed(1)}%',
          description: 'Peak demand grew from ₹${comparison.previous!.billingDemand.toStringAsFixed(1)} to ${comparison.current.billingDemand.toStringAsFixed(1)} kVA.',
          severity: comparison.demandPercentChange > 10 ? InsightSeverity.warning : InsightSeverity.neutral,
          recommendation: 'Check for new equipment added or change in operating pattern.',
        ));
      }
    }

    return items;
  }

  static List<InsightItem> _efficiencyInsights(BillBreakdown breakdown, BusinessKpi kpis) {
    final items = <InsightItem>[];

    items.add(InsightItem(
      title: 'Bill Health Score: ${kpis.billHealthScore.toStringAsFixed(0)}/100',
      description: kpis.billHealthScore >= 80
          ? 'Your billing parameters are well-optimized.'
          : kpis.billHealthScore >= 60
              ? 'Some areas need attention. Review insights below.'
              : 'Multiple issues detected. Immediate action recommended.',
      severity: kpis.billHealthScore >= 80
          ? InsightSeverity.positive
          : kpis.billHealthScore >= 60
              ? InsightSeverity.warning
              : InsightSeverity.critical,
    ));

    if (breakdown.loadFactor > 0) {
      items.add(InsightItem(
        title: 'Load Factor: ${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
        description: breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
            ? 'Good load factor. Your energy usage pattern is consistent and efficient.'
            : 'Low load factor indicates high peaks relative to average. Consider load smoothing.',
        severity: breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
            ? InsightSeverity.positive
            : InsightSeverity.warning,
        recommendation: breakdown.loadFactor < AppConstants.loadFactorThresholdGood
            ? 'Shift some loads to off-peak hours to reduce peak demand. This can lower demand charges.'
            : null,
      ));
    }

    return items;
  }

  static List<InsightItem> _currentUnbalanceInsights(List<EnergyLogEntity> logs) {
    final items = <InsightItem>[];
    final unbalanceLogs = <String, List<EnergyLogEntity>>{};

    for (final log in logs) {
      if (log.kwh <= 0) continue;
      final lagPct = log.rkvarhLag / log.kwh * 100;
      final leadPct = log.rkvarhLead / log.kwh * 100;
      if (lagPct > 5 && leadPct > 5) {
        unbalanceLogs.putIfAbsent(log.meterName, () => []).add(log);
      }
    }

    for (final entry in unbalanceLogs.entries) {
      final meterLogs = entry.value;
      final maxLag = meterLogs.map((l) => l.rkvarhLag / l.kwh * 100).reduce((a, b) => a > b ? a : b);
      final maxLead = meterLogs.map((l) => l.rkvarhLead / l.kwh * 100).reduce((a, b) => a > b ? a : b);
      items.add(InsightItem(
        title: 'Current Unbalance on ${entry.key}',
        description: 'Both lagging (${maxLag.toStringAsFixed(0)}%) and leading (${maxLead.toStringAsFixed(0)}%) reactive power detected — indicates phase unbalance across ${meterLogs.length} reading(s).',
        severity: InsightSeverity.warning,
        recommendation: 'Check phase currents and load distribution. Investigate single-phase loads or faulty capacitor bank contactor.',
      ));
    }

    return items;
  }

  static List<InsightItem> _costInsights(BillBreakdown breakdown, MonthComparison? comparison) {
    final items = <InsightItem>[];

    final chargeLabels = ['Energy Charges', 'Demand Charges', 'FAC', 'Wheeling', 'Taxes & Duty'];
    final chargePcts = [
      breakdown.energyChargesPercent,
      breakdown.demandChargesPercent,
      breakdown.facPercent,
      breakdown.wheelingPercent,
      breakdown.taxesPercent + breakdown.dutyPercent,
    ];
    int topIdx = 0;
    for (int i = 1; i < chargePcts.length; i++) {
      if (chargePcts[i] > chargePcts[topIdx]) topIdx = i;
    }
    final topLabel = chargeLabels[topIdx];
    final topPct = chargePcts[topIdx];
    if (topPct > 0) {
      items.add(InsightItem(
        title: '$topLabel is ${topPct.toStringAsFixed(0)}% of Bill',
        description: topPct > 50
            ? 'Focus on reducing $topLabel for maximum savings impact.'
            : 'Your bill is well-distributed across components.',
        severity: InsightSeverity.neutral,
      ));
    }

    final savings = breakdown.pfRebate - breakdown.pfSurcharge;
    if (savings > 0) {
      items.add(InsightItem(
        title: 'PF Rebate Earned: ₹${breakdown.pfRebate.toStringAsFixed(0)}',
        description: 'Good PF management earned you ₹${breakdown.pfRebate.toStringAsFixed(0)} in rebates.',
        severity: InsightSeverity.positive,
      ));
    } else if (breakdown.pfSurcharge > 0) {
      items.add(InsightItem(
        title: 'PF Penalty: ₹${breakdown.pfSurcharge.toStringAsFixed(0)}',
        description: 'You paid ₹${breakdown.pfSurcharge.toStringAsFixed(0)} in PF penalty. This is avoidable.',
        severity: InsightSeverity.critical,
        recommendation: 'Cost of capacitor bank is typically recovered in 3-6 months through penalty savings.',
      ));
    }

    return items;
  }
}
