import '../../domain/entities/energy_log_entity.dart';
import 'bill_breakdown.dart';

/// One PF measurement for the trend chart / anomaly list.
class PfSample {
  final DateTime date;
  final double pf;
  const PfSample(this.date, this.pf);
}

/// Management-summary status traffic light.
enum SigStatus { green, yellow, red }

class IntelligenceFinding {
  final SigStatus status;
  final String text;
  const IntelligenceFinding(this.status, this.text);
}

class CostShareRow {
  final String label;
  final double amount;
  double percent;
  CostShareRow(this.label, this.amount, this.percent);
}

class OpportunityRow {
  final String area;
  final SigStatus status;
  final String statusLabel;
  final String potential;
  final String note;
  const OpportunityRow({
    required this.area,
    required this.status,
    required this.statusLabel,
    required this.potential,
    required this.note,
  });
}

class TopDay {
  final DateTime date;
  final double kwh;
  const TopDay(this.date, this.kwh);
}

/// Single source of truth for every executive KPI and automated insight.
///
/// Everything an executive report needs is derived ONCE from the raw logs +
/// the billing breakdown, so the summary, trend, anomalies, cost analysis,
/// incentives, opportunities and the conclusion all agree with each other.
class EnergyIntelligence {
  final List<EnergyLogEntity> logs;
  final BillBreakdown b;

  /// Active energy (raw Σ kWh, without the meter factor) — the executive
  /// "consumption" figure.
  final double totalKwh;

  /// Billed units (Σ kVAh × meter factor) — what the bill is actually on.
  final double billedUnits;

  // ── Power Factor ────────────────────────────────────────────────
  final double avgPf;
  final double bestPf;
  final double worstPf;
  final List<PfSample> pfSeries;
  final List<PfSample> lowPfEvents;

  // ── Demand ──────────────────────────────────────────────────────
  final double measuredPeakMd;
  final double billingDemand;
  final double contractDemand;
  final double billingUtilPct;
  final double peakUtilPct;

  // ── Consumption events ──────────────────────────────────────────
  final List<TopDay> topDays;
  final int missingDayCount;

  // ── Cost ────────────────────────────────────────────────────────
  final List<CostShareRow> costShare;
  final double incentivesTotal;

  // ── Confidence ──────────────────────────────────────────────────
  final double confidenceScore;
  final int flaggedInvalid;

  // ── Outputs ─────────────────────────────────────────────────────
  final List<IntelligenceFinding> findings;
  final List<OpportunityRow> opportunities;

  /// Thresholds used across the engine (single source of truth).
  static const double pfLowWarn = 0.95;
  static const double pfLowAlert = 0.90;

  EnergyIntelligence._({
    required this.logs,
    required this.b,
    required this.totalKwh,
    required this.billedUnits,
    required this.avgPf,
    required this.bestPf,
    required this.worstPf,
    required this.pfSeries,
    required this.lowPfEvents,
    required this.measuredPeakMd,
    required this.billingDemand,
    required this.contractDemand,
    required this.billingUtilPct,
    required this.peakUtilPct,
    required this.topDays,
    required this.missingDayCount,
    required this.costShare,
    required this.incentivesTotal,
    required this.confidenceScore,
    required this.flaggedInvalid,
    required this.findings,
    required this.opportunities,
  });

  factory EnergyIntelligence.from(List<EnergyLogEntity> logs, BillBreakdown b) {
    final totalKwh = logs.fold<double>(0, (s, l) => s + l.kwh);
    final totalKvah = logs.fold<double>(0, (s, l) => s + l.kvah);

    // Per-reading PF (EMS measured basis) — matches the audit's billing method.
    final measured = <PfSample>[];
    var flaggedInvalid = 0;
    for (final l in logs) {
      final pf = l.kvah > 0 ? (l.kwh / l.kvah).clamp(0.0, 1.0) : 0.0;
      measured.add(PfSample(l.loggedAt, pf));
      if (l.kwh > 0 && l.kvah > 0 && l.kwh > l.kvah) flaggedInvalid++;
    }
    measured.sort((a, x) => a.date.compareTo(x.date));

    var bestPf = 0.0, worstPf = 0.0;
    if (measured.isNotEmpty) {
      bestPf = measured.map((s) => s.pf).reduce((a, x) => x > a ? x : a);
      worstPf = measured.map((s) => s.pf).reduce((a, x) => (x < a ? x : a));
    }

    final lowPfEvents = measured
        .where((s) => s.pf > 0 && s.pf < EnergyIntelligence.pfLowWarn)
        .toList();

    // Aggregate PF — utility billing method (ΣkWh ÷ ΣkVAh).
    final avgPf = totalKvah > 0 ? (totalKwh / totalKvah).clamp(0.0, 1.0) : 0.0;

    // ── Demand ────────────────────────────────────────────────────
    final measuredPeakMd = logs.fold<double>(
      0,
      (peak, l) => l.mdRecorded * l.multiplyingFactor > peak
          ? l.mdRecorded * l.multiplyingFactor
          : peak,
    );
    final billingUtilPct = b.contractDemand > 0
        ? b.billingDemand / b.contractDemand * 100
        : 0.0;
    final peakUtilPct = b.contractDemand > 0
        ? measuredPeakMd / b.contractDemand * 100
        : 0.0;

    // ── Top consumption days (actual kWh = raw × MF) ──────────────
    final byDay = <String, double>{};
    for (final l in logs) {
      final d = DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day);
      final key = d.toIso8601String();
      byDay.update(
        key,
        (v) => v + l.kwh * l.multiplyingFactor,
        ifAbsent: () => l.kwh * l.multiplyingFactor,
      );
    }
    final days = byDay.entries.toList()
      ..sort((a, x) => x.value.compareTo(a.value));
    final topDays = days
        .take(5)
        .map((e) => TopDay(DateTime.parse(e.key), e.value))
        .toList();

    // Calendar gaps in the recorded window (only meaningful when a daily
    // reading model is present — at least 2 distinct days in the window).
    int missingDayCount = 0;
    if (byDay.length >= 2) {
      final sortedDays = byDay.keys.map(DateTime.parse).toList()
        ..sort((a, x) => a.compareTo(x));
      final range = sortedDays.last.difference(sortedDays.first).inDays;
      missingDayCount = range - (sortedDays.length - 1);
      if (missingDayCount < 0) missingDayCount = 0;
    }

    // ── Cost share (gross charges before incentives/deductions) ───
    final costShare = <CostShareRow>[
      if (b.energyCharges != 0)
        CostShareRow('Energy Charges', b.energyCharges, 0),
      if (b.demandCharges != 0)
        CostShareRow('Demand Charges', b.demandCharges, 0),
      if (b.facCharges != 0) CostShareRow('FAC', b.facCharges, 0),
      if (b.wheelingCharges != 0)
        CostShareRow('Wheeling', b.wheelingCharges, 0),
      if (b.electricityDuty != 0)
        CostShareRow('Electricity Duty', b.electricityDuty, 0),
      if (b.taxes != 0) CostShareRow('Taxes', b.taxes, 0),
      if (b.todCharges != 0) CostShareRow('TOD', b.todCharges, 0),
      if (b.fixedCharge != 0) CostShareRow('Fixed Charge', b.fixedCharge, 0),
      if (b.arrearsDpc != 0) CostShareRow('Arrears/DPC', b.arrearsDpc, 0),
    ];
    final grossTotal = costShare.fold<double>(0, (s, c) => s + c.amount);
    for (final c in costShare) {
      c.percent = grossTotal > 0 ? c.amount / grossTotal * 100 : 0.0;
    }

    // ── Incentives earned (rebates that reduce the bill) ──────────
    final incentivesTotal =
        b.pfRebate +
        b.lfIncentive +
        b.icrRebate +
        b.ppdRebate +
        b.bulkRebate +
        b.regionSubsidy +
        b.rebateSection106 +
        b.goMSubsidyFixed +
        b.goMSubsidyTod;

    // ── Confidence score ──────────────────────────────────────────
    var score = 100.0;
    score -= flaggedInvalid * 10;
    score -= lowPfEvents.length * 2;
    score -= (missingDayCount * 1).clamp(0, 10);
    if (avgPf > 0 && avgPf < EnergyIntelligence.pfLowWarn) score -= 5;
    if (measuredPeakMd > b.contractDemand && b.contractDemand > 0) score -= 5;
    final confidenceScore = score.clamp(0.0, 100.0);

    // ── Management findings ───────────────────────────────────────
    final findings = <IntelligenceFinding>[];
    if (avgPf >= EnergyIntelligence.pfLowWarn) {
      findings.add(
        IntelligenceFinding(
          SigStatus.green,
          'PF performance generally healthy (${avgPf.toStringAsFixed(3)})',
        ),
      );
    } else {
      findings.add(
        IntelligenceFinding(
          SigStatus.yellow,
          'Intermittent low-PF events detected (worst ${worstPf.toStringAsFixed(3)})',
        ),
      );
    }
    if (billingUtilPct >= 85) {
      findings.add(
        IntelligenceFinding(
          SigStatus.red,
          'Demand utilization ${billingUtilPct.toStringAsFixed(0)}% - close to contract',
        ),
      );
    } else if (billingUtilPct >= 65) {
      findings.add(
        IntelligenceFinding(
          SigStatus.yellow,
          'Demand utilization ${billingUtilPct.toStringAsFixed(0)}%',
        ),
      );
    } else {
      findings.add(
        IntelligenceFinding(
          SigStatus.green,
          'Demand utilization ${billingUtilPct.toStringAsFixed(0)}% - headroom available',
        ),
      );
    }
    if (flaggedInvalid > 0) {
      findings.add(
        IntelligenceFinding(
          SigStatus.red,
          '$flaggedInvalid reading(s) with kWh > kVAh - requires validation',
        ),
      );
    } else if (missingDayCount > 0) {
      findings.add(
        IntelligenceFinding(
          SigStatus.yellow,
          '$missingDayCount calendar day(s) without a reading - gaps in consumption record',
        ),
      );
    } else {
      findings.add(
        IntelligenceFinding(
          SigStatus.green,
          'Consumption record consistent (no missing readings)',
        ),
      );
    }
    if (incentivesTotal > 0) {
      findings.add(
        IntelligenceFinding(
          SigStatus.green,
          'Rs. ${incentivesTotal.toStringAsFixed(0)} incentives/rebates received',
        ),
      );
    } else {
      findings.add(
        IntelligenceFinding(
          SigStatus.yellow,
          'No rebates/incentives applied this period',
        ),
      );
    }

    // ── Opportunities ─────────────────────────────────────────────
    final opportunities = <OpportunityRow>[];
    if (lowPfEvents.isNotEmpty) {
      opportunities.add(
        OpportunityRow(
          area: 'Power Factor',
          status: SigStatus.red,
          statusLabel: 'Analyze',
          potential: 'Potential',
          note:
              '${lowPfEvents.length} low-PF event(s) below ${pfLowWarn.toStringAsFixed(2)} - APFC / capacitor check recommended',
        ),
      );
    } else {
      opportunities.add(
        OpportunityRow(
          area: 'Power Factor',
          status: SigStatus.green,
          statusLabel: 'Healthy',
          potential: 'None',
          note:
              'Average PF ${avgPf.toStringAsFixed(3)} - no intervention needed',
        ),
      );
    }
    if (peakUtilPct >= 100) {
      opportunities.add(
        OpportunityRow(
          area: 'Peak Demand',
          status: SigStatus.red,
          statusLabel: 'Review',
          potential: 'High',
          note:
              'Measured peak ${measuredPeakMd.toStringAsFixed(1)} kVA touches contract ${b.contractDemand.toStringAsFixed(0)} kVA',
        ),
      );
    } else if (peakUtilPct >= 80) {
      opportunities.add(
        OpportunityRow(
          area: 'Peak Demand',
          status: SigStatus.yellow,
          statusLabel: 'Monitor',
          potential: 'Potential',
          note:
              'Measured peak ${measuredPeakMd.toStringAsFixed(1)} kVA is ${peakUtilPct.toStringAsFixed(0)}% of contract',
        ),
      );
    } else {
      opportunities.add(
        OpportunityRow(
          area: 'Peak Demand',
          status: SigStatus.green,
          statusLabel: 'Monitor',
          potential: 'Low',
          note:
              'Peak utilisation ${peakUtilPct.toStringAsFixed(0)}% - room before contract upgrade',
        ),
      );
    }
    if (b.todCharges != 0 && grossTotal > 0) {
      final todShare = b.todCharges / grossTotal * 100;
      opportunities.add(
        OpportunityRow(
          area: 'TOD Consumption',
          status: todShare >= 15 ? SigStatus.yellow : SigStatus.green,
          statusLabel: todShare >= 15 ? 'Review' : 'OK',
          potential: todShare >= 15 ? 'Potential' : 'Low',
          note:
              'TOD represents ${todShare.toStringAsFixed(1)}% of gross charges - shift load from peak zones where possible',
        ),
      );
    }
    if (topDays.length >= 2) {
      final avgDay = totalKwh <= 0 || days.isEmpty
          ? 0.0
          : days.fold<double>(0, (s, d) => s + d.value) / days.length;
      final minDay = days.last.value;
      final baseRatio = avgDay > 0 ? minDay / avgDay : 0.0;
      if (baseRatio < 0.5) {
        opportunities.add(
          OpportunityRow(
            area: 'Base Load',
            status: SigStatus.yellow,
            statusLabel: 'Monitor',
            potential: 'Potential',
            note:
                'Lowest day is ${(baseRatio * 100).toStringAsFixed(0)}% of average - review non-production base load',
          ),
        );
      } else {
        opportunities.add(
          OpportunityRow(
            area: 'Base Load',
            status: SigStatus.green,
            statusLabel: 'OK',
            potential: 'Low',
            note: 'Base load consistent across days',
          ),
        );
      }
    }
    opportunities.add(
      OpportunityRow(
        area: 'Incentives',
        status: incentivesTotal > 0 ? SigStatus.green : SigStatus.yellow,
        statusLabel: incentivesTotal > 0 ? 'Active' : 'Check',
        potential: incentivesTotal > 0
            ? 'Rs. ${incentivesTotal.toStringAsFixed(0)}'
            : 'Potential',
        note: incentivesTotal > 0
            ? 'PF + load-factor incentives already credited'
            : 'Verify eligibility for PF/load-factor rebates',
      ),
    );

    return EnergyIntelligence._(
      logs: logs,
      b: b,
      totalKwh: totalKwh,
      billedUnits: b.totalUnits,
      avgPf: avgPf,
      bestPf: bestPf,
      worstPf: worstPf,
      pfSeries: measured,
      lowPfEvents: lowPfEvents,
      measuredPeakMd: measuredPeakMd,
      billingDemand: b.billingDemand,
      contractDemand: b.contractDemand,
      billingUtilPct: billingUtilPct,
      peakUtilPct: peakUtilPct,
      topDays: topDays,
      missingDayCount: missingDayCount,
      costShare: costShare,
      incentivesTotal: incentivesTotal,
      confidenceScore: confidenceScore,
      flaggedInvalid: flaggedInvalid,
      findings: findings,
      opportunities: opportunities,
    );
  }
}
