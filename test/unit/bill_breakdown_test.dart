import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_calculator.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required double kwh,
  required double kvah,
  required double md,
  double contractDemand = 400,
  String meterName = 'Meter-01',
  double multiplyingFactor = 5,
}) {
  return EnergyLogEntity(
    id: '$meterName-$kwh-$kvah-$md',
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
    multiplyingFactor: multiplyingFactor,
  );
}

void main() {
  group('BillCalculator.calculate', () {
    test('computes charges for a single reading', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 300)],
      );

      expect(breakdown.totalUnits, 1250); // 250 kVAh × 5 MF (billed on kVAh)
      expect(breakdown.powerFactor, closeTo(0.800, 0.001));
      expect(breakdown.billingDemand, 1500); // recorded 300 raw × 5 MF
      expect(breakdown.energyCharges, closeTo(10550, 0.01)); // 1250 × 8.44
      expect(breakdown.demandCharges, closeTo(975000, 0.01)); // 1500 × 650
      expect(breakdown.facCharges, closeTo(375, 0.01)); // 1250 × 0.30
      expect(breakdown.wheelingCharges, closeTo(1012.5, 0.01)); // 1250 × 0.81
      expect(breakdown.electricityDuty, closeTo(343.75, 0.01)); // 1250 × 0.275
      expect(breakdown.taxes, closeTo(131.88, 0.01)); // 1.25% of 10550 energy
      expect(breakdown.pfSurcharge, closeTo(49277.5, 0.01)); // PF 0.8 < 0.9 → 5%
      expect(breakdown.pfRebate, 0);
      expect(breakdown.loadFactor, 1.0);
    });

    test('applies PF rebate when power factor >= threshold', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 200, md: 300)],
      );

      expect(breakdown.powerFactor, 1.0);
      expect(breakdown.pfRebate, closeTo(9834.4, 0.01)); // 1% of (8440+975000)
      expect(breakdown.pfSurcharge, 0);
    });

    test('respects a custom energy rate', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 200, kvah: 250, md: 300)],
        energyRate: 10.0,
      );

      expect(breakdown.energyCharges, closeTo(12500, 0.01)); // 1250 kVAh × 10
    });

    test('billing demand uses recorded MD — 75% is reference only', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 100, kvah: 120, md: 50)],
        contractDemand: 400,
      );

      expect(breakdown.billingDemand, 250); // 50 × 5 MF — no contract floor
    });

    test('ratchet: preceding month peak (MD × MF) is considered', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 100, kvah: 120, md: 10)],
        contractDemand: 400,
        ratchetLogs: [
          EnergyLogEntity(
            id: 'dec',
            meterName: 'Meter-01',
            kwh: 90,
            kvah: 100,
            rkvarhLag: 0,
            rkvarhLead: 0,
            powerFactor: 0.9,
            mdRecorded: 60, // Dec 2025 → 60 × 5 = 300
            contractDemand: 400,
            estimatedBill: 0,
            loggedAt: DateTime(2025, 12, 15),
            multiplyingFactor: 5,
          ),
        ],
      );

      expect(breakdown.billingDemand, 300); // ratchet peak beats current + floor
    });

    test('ratchet: current month demand breaks the ratchet peak', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 100, kvah: 120, md: 100)],
        contractDemand: 400,
        ratchetLogs: [
          EnergyLogEntity(
            id: 'dec',
            meterName: 'Meter-01',
            kwh: 90,
            kvah: 100,
            rkvarhLag: 0,
            rkvarhLead: 0,
            powerFactor: 0.9,
            mdRecorded: 60, // 60 × 5 = 300
            contractDemand: 400,
            estimatedBill: 0,
            loggedAt: DateTime(2025, 12, 15),
            multiplyingFactor: 5,
          ),
        ],
      );

      expect(breakdown.billingDemand, 500); // 100 × 5 = 500 > 300
    });

    test('ratchet: peaks older than the window are ignored', () {
      final breakdown = BillCalculator.calculate(
        logs: [_log(kwh: 100, kvah: 120, md: 10)],
        contractDemand: 400,
        ratchetLogs: [
          EnergyLogEntity(
            id: 'old',
            meterName: 'Meter-01',
            kwh: 90,
            kvah: 100,
            rkvarhLag: 0,
            rkvarhLead: 0,
            powerFactor: 0.9,
            mdRecorded: 500, // Jan 2025 — outside 11-month window
            contractDemand: 400,
            estimatedBill: 0,
            loggedAt: DateTime(2025, 1, 15),
            multiplyingFactor: 5,
          ),
        ],
      );

      expect(breakdown.billingDemand, 50); // 10 × 5 MF — no floor, no ratchet
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
      expect(comparison.unitDifference, closeTo(650, 0.01)); // 1250 − 600 kVAh
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
        logs: [_log(kwh: 200, kvah: 200, md: 60)], // 60 × 5 = 300 ≤ 400
        contractDemand: 400,
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
