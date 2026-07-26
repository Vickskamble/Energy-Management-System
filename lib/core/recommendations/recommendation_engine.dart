import '../constants/app_constants.dart';
import '../calculation/bill_breakdown.dart';
import '../../domain/entities/energy_log_entity.dart';

class RecommendationItem {
  final String title;
  final String description;
  final String action;
  final String impact;
  final double? estimatedSavings;
  final int priority;

  const RecommendationItem({
    required this.title,
    required this.description,
    required this.action,
    required this.impact,
    this.estimatedSavings,
    this.priority = 5,
  });
}

class RecommendationEngine {
  RecommendationEngine._();

  static List<RecommendationItem> generate({
    required BillBreakdown breakdown,
    required MonthComparison? comparison,
    required List<EnergyLogEntity> logs,
  }) {
    final items = <RecommendationItem>[];

    items.addAll(_pfRecommendations(breakdown));
    items.addAll(_demandRecommendations(breakdown, comparison));
    items.addAll(_energyEfficiencyRecommendations(breakdown, logs));
    items.addAll(_tariffRecommendations(breakdown));

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items;
  }

  static List<RecommendationItem> _pfRecommendations(BillBreakdown breakdown) {
    final items = <RecommendationItem>[];

    if (breakdown.powerFactor < AppConstants.pfSurchargeThreshold) {
      final penalty = breakdown.pfSurcharge;
      final capacitorKvar = ((1 / breakdown.powerFactor - 1 / AppConstants.pfRebateThreshold) * breakdown.billingDemand);
      items.add(RecommendationItem(
        title: 'Urgent: Improve Power Factor',
        description: 'PF is ${breakdown.powerFactor.toStringAsFixed(3)} causing ₹${penalty.toStringAsFixed(0)}/month penalty.',
        action: 'Install ${capacitorKvar.toStringAsFixed(0)} kVAr capacitor bank. Target PF > 0.95.',
        impact: 'Save ₹${(penalty + breakdown.energyCharges * AppConstants.pfRebatePercent / 100).toStringAsFixed(0)}/month',
        estimatedSavings: penalty + breakdown.energyCharges * AppConstants.pfRebatePercent / 100,
        priority: 10,
      ));
    } else if (breakdown.powerFactor < AppConstants.pfRebateThreshold) {
      final potentialRebate = breakdown.energyCharges * AppConstants.pfRebatePercent / 100;
      items.add(RecommendationItem(
        title: 'Improve PF to Earn Rebate',
        description: 'PF is ${breakdown.powerFactor.toStringAsFixed(3)}. Just ${((AppConstants.pfRebateThreshold - breakdown.powerFactor) * 100).toStringAsFixed(1)}% away from ${AppConstants.pfRebatePercent}% rebate.',
        action: 'Check APFC controller settings. Add small capacitor bank if needed.',
        impact: 'Earn ₹${potentialRebate.toStringAsFixed(0)}/month rebate',
        estimatedSavings: potentialRebate,
        priority: 8,
      ));
    }

    return items;
  }

  static List<RecommendationItem> _demandRecommendations(BillBreakdown breakdown, MonthComparison? comparison) {
    final items = <RecommendationItem>[];

    final demandUtil = breakdown.contractDemand > 0
        ? (breakdown.billingDemand / breakdown.contractDemand * 100)
        : 0.0;

    if (demandUtil > 85) {
      final potentialPenalty = (breakdown.billingDemand - breakdown.contractDemand) * AppConstants.demandChargePerKva;
      items.add(RecommendationItem(
        title: 'Reduce Peak Demand',
        description: 'Demand at ${demandUtil.toStringAsFixed(0)}% of contract. Risk of excess demand penalty of ₹${potentialPenalty.toStringAsFixed(0)}.',
        action: 'Shift non-critical loads (HVAC, pumps, compressors) to off-peak hours. Use demand controller.',
        impact: 'Avoid ₹${potentialPenalty.toStringAsFixed(0)} penalty and reduce demand charges',
        estimatedSavings: potentialPenalty,
        priority: 9,
      ));
    } else if (demandUtil < 50) {
      final currentCharge = breakdown.billingDemand * AppConstants.demandChargePerKva;
      final suggestedDemand = breakdown.billingDemand * 1.2;
      final newCharge = suggestedDemand * AppConstants.demandChargePerKva;
      items.add(RecommendationItem(
        title: 'Reduce Contract Demand',
        description: 'Current utilization is ${demandUtil.toStringAsFixed(0)}%. You may be overpaying for capacity.',
        action: 'Apply to reduce contract demand from ${breakdown.contractDemand.toStringAsFixed(0)} to ${suggestedDemand.toStringAsFixed(0)} kVA.',
        impact: 'Save ₹${(currentCharge - newCharge).toStringAsFixed(0)}/month on demand charges',
        estimatedSavings: (currentCharge - newCharge).clamp(0, double.infinity),
        priority: 6,
      ));
    }

    if (comparison != null && comparison.isDemandIncreased && comparison.demandPercentChange > 15) {
      items.add(RecommendationItem(
        title: 'Investigate Demand Increase',
        description: 'Peak demand increased by ${comparison.demandPercentChange.toStringAsFixed(0)}%.',
        action: 'Review if new equipment was added. Check if multiple high-load devices run simultaneously.',
        impact: 'Identify root cause to control future demand growth',
        priority: 7,
      ));
    }

    return items;
  }

  static List<RecommendationItem> _energyEfficiencyRecommendations(BillBreakdown breakdown, List<EnergyLogEntity> logs) {
    final items = <RecommendationItem>[];

    if (breakdown.loadFactor < AppConstants.loadFactorThresholdGood && breakdown.loadFactor > 0) {
      items.add(RecommendationItem(
        title: 'Improve Load Factor',
        description: 'Load factor is ${(breakdown.loadFactor * 100).toStringAsFixed(0)}%. Low load factor means high peaks.',
        action: 'Implement load scheduling. Use energy storage or backup DG during peaks.',
        impact: 'Reduce demand charges and improve equipment utilization',
        priority: 6,
      ));
    }

    if (breakdown.averageUnitCost > 10) {
      items.add(RecommendationItem(
        title: 'Review Tariff Category',
        description: 'Average unit cost is ₹${breakdown.averageUnitCost.toStringAsFixed(2)} which is on the higher side.',
        action: 'Check if you are on the correct tariff category. Consider Time-of-Day tariff if available.',
        impact: 'Potential 5-10% reduction in energy charges',
        priority: 5,
      ));
    }

    return items;
  }

  static List<RecommendationItem> _tariffRecommendations(BillBreakdown breakdown) {
    final items = <RecommendationItem>[];

    final nonEnergyPct = breakdown.energyChargesPercent < 50 ? 100 - breakdown.energyChargesPercent : 0;
    if (nonEnergyPct > 40) {
      items.add(RecommendationItem(
        title: 'Non-Energy Charges are ${nonEnergyPct.toStringAsFixed(0)}% of Bill',
        description: 'A significant portion of your bill is non-energy charges.',
        action: 'Review wheeling charges, FAC, and duties. Ensure all calculations are correct.',
        impact: 'Potential savings of 5-15% through tariff optimization',
        priority: 4,
      ));
    }

    return items;
  }
}
