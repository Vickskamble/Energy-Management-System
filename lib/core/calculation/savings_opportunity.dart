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

    if (breakdown.billingDemand > floor) {
      final reducedBilling = max(floor, breakdown.billingDemand * 0.9);
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
                'Peak demand 10% kam karne se demand charges me direct bachat.',
            action:
                'Heavy machines ko alag-alag time par chalao, peak ek saath na aaye',
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
              ? 'Abhi ${AppConstants.pfSurchargePercent.toInt()}% surcharge lag raha hai, rebate bhi miss ho rahi hai.'
              : 'Rebate boundary se thoda neeche ho — thoda improvement me rebate mil jayegi.',
          action: 'APFC panel / capacitor bank check karo',
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
                'Load smooth karo — Load Factor ${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
            description:
                'Peak ko flat karne se demand charges ghatenge bina consumption kam kiye.',
            action: 'High-power loads ko peak hours se bahar shift karo',
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
  /// Jab last 6 months ka peak MD contract demand ke 80% se bhi kam ho to
  /// contract kam karne ki suggestion — direct ₹ bachat.
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

    // Sirf tab suggest karo jab kaafi history ho (>= 6 months data).
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
          'Last 6 months ka peak MD sirf ${maxPeak.toStringAsFixed(0)} kVA hai — '
          'contract demand ${((maxPeak / contractDemand) * 100).toStringAsFixed(0)}% use ho raha hai.',
      action:
          'Utility se contract demand reduce karne ke liye apply karo (rate revision ke saath compare karke)',
      monthlySavings: savings,
    );
  }
}
