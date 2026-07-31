import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_breakdown.dart';
import 'package:ems/core/calculation/bill_calculator.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required double kwh,
  required double kvah,
  required double md,
  double contractDemand = 400,
  String meterName = 'Meter-01',
}) {
  return EnergyLogEntity(
    id: '${meterName}-$kwh-$kvah-$md',
    meterName: meterName,
    kwh: kwh,
    kvah: kvah,
    rkvarhLag: 0,
    rkvarhLead: 0,
    powerFactor: kwh > 0 && kvah > 0 ? (kwh / kvah).clamp(0.0, 1.0) : 0,
    mdRecorded: md,
    contractDemand: contractDemand,
    estimatedBill: 0,
    loggedAt: DateTime(2026, 1, 10),
  );
}

void main() {
  group('BillCalculator.calculate', () {
    test('computes charges for a single reading', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 300)],
      );

      expect(breakdown.totalUnits, 1000); // 200 kWh × 5 MF
      expect(breakdown.powerFactor, closeTo(0.800, 0.001));
      expect(breakdown.billingDemand, 300); // max(300, 400×0.75)
      expect(breakdown.energyCharges, closeTo(8680, 0.01)); // 1000 × 8.68
      expect(breakdown.demandCharges, closeTo(96000, 0.01)); // 300 × 320
      expect(breakdown.facCharges, closeTo(850, 0.01));
      expect(breakdown.wheelingCharges, closeTo(650, 0.01));
      expect(breakdown.electricityDuty, closeTo(5309, 0.01));
      expect(breakdown.taxes, closeTo(557.45, 0.01));
      expect(breakdown.pfSurcharge, closeTo(5234, 0.01)); // PF 0.8 < 0.9
      expect(breakdown.pfRebate, 0);
      expect(breakdown.netBill, closeTo(117280.45, 0.02));
      expect(breakdown.loadFactor, 1.0);
    });

    test('applies PF rebate when power factor >= threshold', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 200, md: 300)],
      );

      expect(breakdown.powerFactor, 1.0);
      expect(breakdown.pfRebate, closeTo(1046.8, 0.01)); // 1% of energy+demand
      expect(breakdown.pfSurcharge, 0);
    });

    test('respects a custom energy rate', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 300)],
        energyRate: 10.0,
      );

      expect(breakdown.energyCharges, closeTo(10000, 0.01));
    });

    test('billing demand never falls below 75% of contract demand', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 100, kvah: 120, md: 50)],
      );

      expect(breakdown.billingDemand, 300); // 400 × 0.75 floor
    });

    test('returns zeroed breakdown for empty logs', () {
      final breakdown = BillCalculator.calculate(logs: const []);

      expect(breakdown.netBill, 0);
      expect(breakdown.totalUnits, 0);
      expect(breakdown.powerFactor, 0);
    });
  });

  group('BillCalculator.compare', () {
    final current = BillCalculator.calculate(
      logs: [_log(kwh: 200, kvah: 250, md: 300)],
    );
    final previous = BillCalculator.calculate(
      logs: [_log(kwh: 100, kvah: 120, md: 200)],
    );

    test('computes difference and percent change', () {
      final comparison = BillCalculator.compare(current, previous);

      expect(comparison.isBillIncreased, current.netBill > previous.netBill);
      expect(
        comparison.billDifference,
        closeTo(current.netBill - previous.netBill, 0.01),
      );
      expect(
        comparison.billPercentChange,
        closeTo(
          (current.netBill - previous.netBill) / previous.netBill * 100,
          0.01,
        ),
      );
      expect(comparison.unitDifference, closeTo(500, 0.01)); // 1000 - 500
    });

    test('handles null previous month', () {
      final comparison = BillCalculator.compare(current, null);

      expect(comparison.billDifference, 0);
      expect(comparison.billPercentChange, 0);
      expect(comparison.previous, isNull);
    });
  });

  group('BillCalculator.calculateKpis', () {
    test('perfect parameters score 100', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 200, md: 300)],
      );
      final kpis = BillCalculator.calculateKpis(breakdown);

      expect(kpis.billHealthScore, 100);
    });

    test('poor power factor lowers score', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 500, md: 300)],
      );
      final kpis = BillCalculator.calculateKpis(breakdown);

      expect(kpis.billHealthScore, lessThan(100));
      expect(kpis.energyScore, lessThan(100));
    });
  });
}
