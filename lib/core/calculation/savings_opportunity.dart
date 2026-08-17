import 'dart:math';
import '../../domain/entities/energy_log_entity.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'bill_breakdown.dart';

enum SavingType {
  demandReduction,
  powerFactorImprovement,
  loadSmoothing,
  contractDemandOptimization,
}

class SavingOpportunity {
  final SavingType type;
  final String title;
  final String description;
  final String action;
  final double monthlySavings;

  const SavingOpportunity({
    required this.type,
    required this.title,
    required this.description,
    required this.action,
    required this.monthlySavings,
  });
}

class SavingOpportunityGenerator {
  SavingOpportunityGenerator._();

  static List<SavingOpportunity> generate(BillBreakdown breakdown) {
    if (breakdown.netBill <= 0) return const [];

    final ops = <SavingOpportunity>[];
    final floor = breakdown.contractDemand * 0.75;

    // Only suggest shaving the peak when demand is already high enough to
    // matter (above 75% of contract). The reduction is a genuine 10% of the
    // billed demand, so the title/description stay consistent with the saving.
    if (breakdown.billingDemand > floor) {
      final reducedBilling = breakdown.billingDemand * 0.9;
      if (reducedBilling < breakdown.billingDemand - 1) {
        final savings =
            (breakdown.billingDemand - reducedBilling) *
            AppConfig.demandChargePerKva;
        ops.add(
          SavingOpportunity(
            type: SavingType.demandReduction,
            title:
                'Max Demand ${breakdown.billingDemand.toStringAsFixed(0)} → ${reducedBilling.toStringAsFixed(0)} kVA',
            description:
                'Lowering peak demand by 10% reduces demand charges directly.',
            action:
                'Stagger heavy machinery operation to avoid simultaneous peaks',
            monthlySavings: savings,
          ),
        );
      }
    }

    if (breakdown.powerFactor < AppConstants.pfRebateThreshold &&
        breakdown.powerFactor > 0) {
      final base = breakdown.energyCharges + breakdown.demandCharges;
      final penalty = breakdown.powerFactor < AppConstants.pfSurchargeThreshold
          ? AppConstants.pfSurchargePercent + AppConstants.pfRebatePercent
          : AppConstants.pfRebatePercent;
      final savings = base * penalty / 100;
      ops.add(
        SavingOpportunity(
          type: SavingType.powerFactorImprovement,
          title:
              'PF ${breakdown.powerFactor.toStringAsFixed(2)} → ${AppConstants.pfRebateThreshold.toStringAsFixed(2)}',
          description: breakdown.powerFactor < AppConstants.pfSurchargeThreshold
              ? 'A ${AppConstants.pfSurchargePercent.toInt()}% surcharge currently applies and you are also missing the rebate.'
              : 'Just below the rebate threshold — a small improvement will earn the rebate.',
          action: 'Check the APFC panel / capacitor bank',
          monthlySavings: savings,
        ),
      );
    }

    if (breakdown.loadFactor > 0 &&
        breakdown.loadFactor < AppConstants.loadFactorThresholdGood) {
      final avgDemand = breakdown.billingDemand * breakdown.loadFactor;
      final targetPeak = avgDemand / 0.85;
      final newBilling = max(floor, targetPeak);
      if (newBilling < breakdown.billingDemand - 1) {
        final savings =
            (breakdown.billingDemand - newBilling) *
            AppConfig.demandChargePerKva;
        ops.add(
          SavingOpportunity(
            type: SavingType.loadSmoothing,
            title:
                'Smooth the load — Load Factor ${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
            description:
                'Flattening the peak reduces demand charges without lowering consumption.',
            action: 'Shift high-power loads outside peak hours',
            monthlySavings: savings,
          ),
        );
      }
    }

    ops.sort((a, b) => b.monthlySavings.compareTo(a.monthlySavings));
    return ops.take(3).toList();
  }

  /// Issue 7C — Contract Demand Optimizer.
  ///
  /// When the last 6 months' peak MD stays below 80% of the contract demand,
  /// suggest lowering the contract — direct ₹ savings.
  static SavingOpportunity? generateContractDemandOptimizer({
    required List<EnergyLogEntity> logs,
    required double contractDemand,
  }) {
    if (logs.isEmpty || contractDemand <= 0) return null;

    final now = DateTime.now();
    final monthlyPeaks = <double>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      var peak = 0.0;
      for (final e in logs) {
        if (e.loggedAt.year == month.year && e.loggedAt.month == month.month) {
          final actualMd = e.mdRecorded * e.multiplyingFactor;
          if (actualMd > peak) peak = actualMd;
        }
      }
      monthlyPeaks.add(peak);
    }

    // Only suggest when there is enough history (>= 6 months of data).
    final monthsWithData = monthlyPeaks.where((p) => p > 0).length;
    if (monthsWithData < 6) return null;

    final maxPeak = monthlyPeaks.reduce(max);
    if (maxPeak >= contractDemand * 0.8) return null;

    // Suggest next standard 50 kVA step above the actual peak.
    final suggested = (maxPeak / 50).ceil() * 50.0;
    if (suggested >= contractDemand) return null;

    final savings =
        (contractDemand - suggested) * AppConfig.demandChargePerKva;
    return SavingOpportunity(
      type: SavingType.contractDemandOptimization,
      title:
          'Contract ${contractDemand.toStringAsFixed(0)} → ${suggested.toStringAsFixed(0)} kVA',
      description:
          'The peak MD over the last 6 months is only ${maxPeak.toStringAsFixed(0)} kVA — '
          '${((maxPeak / contractDemand) * 100).toStringAsFixed(0)}% of the contract demand is being used.',
      action:
          'Apply to the utility to reduce the contract demand (compare with a rate revision first)',
      monthlySavings: savings,
    );
  }
}
