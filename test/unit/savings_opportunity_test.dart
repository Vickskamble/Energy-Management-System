import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_calculator.dart';
import 'package:ems/core/calculation/savings_opportunity.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required double kwh,
  required double kvah,
  required double md,
}) {
  return EnergyLogEntity(
    id: 'log-$kwh-$kvah-$md',
    meterName: 'Meter-01',
    kwh: kwh,
    kvah: kvah,
    rkvarhLag: 0,
    rkvarhLead: 0,
    powerFactor: kwh > 0 && kvah > 0 ? (kwh / kvah).clamp(0.0, 1.0) : 0,
    mdRecorded: md,
    contractDemand: 400,
    estimatedBill: 0,
    loggedAt: DateTime(2026, 1, 10),
    multiplyingFactor: 5,
  );
}

void main() {
  group('SavingOpportunityGenerator.generate', () {
    test('returns empty list when there is no bill', () {
      final empty = BillCalculator.calculate(logs: const []);
      expect(SavingOpportunityGenerator.generate(empty), isEmpty);
    });

    test('suggests demand reduction when billing demand is high', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 500)],
      );
      final ops = SavingOpportunityGenerator.generate(breakdown);

      final demandOp = ops.where((o) => o.type == SavingType.demandReduction);
      expect(demandOp, isNotEmpty);
      // billingDemand=2500 (500 raw × 5 MF), floor=300, reduced=2500×0.9=2250
      // savings = (2500-2250) × ₹650 = ₹162,500
      expect(demandOp.first.monthlySavings, closeTo(162500, 0.01));
    });

    test('suggests PF improvement when power factor is below 0.95', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 300)],
      );
      final ops = SavingOpportunityGenerator.generate(breakdown);

      final pfOp = ops.where(
        (o) => o.type == SavingType.powerFactorImprovement,
      );
      expect(pfOp, isNotEmpty);
      // PF 0.80 < 0.90 → penalty = 5.0 + 1.0 = 6.0%
      // base = 10550 + 975000 = 985550 (energy on kVAh units)
      // savings = 985550 × 6.0 / 100 = 59133.0
      expect(pfOp.first.monthlySavings, closeTo(59133.0, 0.01));
    });

    test('suggests load smoothing when load factor is low', () {
      final breakdown = BillCalculator.calculate(
        logs: [
          _log(kwh: 200, kvah: 250, md: 100),
          _log(kwh: 200, kvah: 250, md: 400),
        ],
        contractDemand: 400,
      );
      final ops = SavingOpportunityGenerator.generate(breakdown);

      final smoothingOp = ops.where((o) => o.type == SavingType.loadSmoothing);
      expect(smoothingOp, isNotEmpty);
      // peaks 500 & 2000 (×5 MF) → billingDemand=2000, avgDemand=1250, LF=0.625
      // targetPeak=1250/0.85=1470.59, newBilling=max(300,1470.59)=1470.59
      // savings = (2000-1470.59) × ₹650 = ₹344,117.65
      expect(smoothingOp.first.monthlySavings, closeTo(344117.65, 0.01));
    });

    test('returns at most 3 opportunities sorted by savings', () {
      final breakdown = BillCalculator.calculate(
        logs: [
          _log(kwh: 200, kvah: 250, md: 500),
          _log(kwh: 200, kvah: 250, md: 400),
        ],
      );
      final ops = SavingOpportunityGenerator.generate(breakdown);

      expect(ops.length, lessThanOrEqualTo(3));
      for (var i = 1; i < ops.length; i++) {
        expect(
          ops[i].monthlySavings,
          lessThanOrEqualTo(ops[i - 1].monthlySavings),
        );
      }
    });
  });

  group('SavingOpportunityGenerator.generateContractDemandOptimizer', () {
    List<EnergyLogEntity> sixMonthsOfLogs({required double md}) {
      final now = DateTime.now();
      return [
        for (var i = 0; i < 6; i++)
          _log(kwh: 200, kvah: 250, md: md).copyWith(
            loggedAt: DateTime(now.year, now.month - i, 10),
          ),
      ];
    }

    test('suggests contract reduction when 6-month peak is well below 80%', () {
      final logs = sixMonthsOfLogs(md: 30); // 30 × 5 MF = 150 kVA peak

      final op = SavingOpportunityGenerator.generateContractDemandOptimizer(
        logs: logs,
        contractDemand: 400,
      );

      expect(op, isNotNull);
      expect(op!.type, SavingType.contractDemandOptimization);
      // 150 kVA peak → suggested = 150
      // savings = (400-150) × ₹650 = ₹162,500
      expect(op.monthlySavings, closeTo(162500, 0.01));
    });

    test('returns null when peak MD is above 80% of contract', () {
      final logs = sixMonthsOfLogs(md: 350); // 350 × 5 = 1750 ≥ 320

      final op = SavingOpportunityGenerator.generateContractDemandOptimizer(
        logs: logs,
        contractDemand: 400,
      );

      expect(op, isNull);
    });

    test('returns null with less than 6 months of data', () {
      final logs = sixMonthsOfLogs(md: 30).sublist(0, 3);

      final op = SavingOpportunityGenerator.generateContractDemandOptimizer(
        logs: logs,
        contractDemand: 400,
      );

      expect(op, isNull);
    });
  });
}
