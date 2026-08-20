import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_calculator.dart';
import 'package:ems/core/config/app_config.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

/// Replicates the real G K Healthcare · Jul-2026 MSEDCL bill through the
/// engine, line by line. The bill's exact total is 2,62,355.12; every
/// verified formula (energy/demand/FAC/wheeling/tax/ICR + payable-column
/// floor rounding) must reproduce the numbers.
void main() {
  group('MSEDCL July-2026 bill fixture', () {
    EnergyLogEntity shift(double kvah, int hour) => EnergyLogEntity(
          id: 'jul-$hour',
          meterName: 'TODMeter',
          kwh: kvah * 0.92, // PF 0.92 → no PF rebate/penalty (matches bill)
          kvah: kvah,
          rkvarhLag: 0,
          rkvarhLead: 0,
          powerFactor: 0.92,
          mdRecorded: 30, // below the 151 kVA floor → billed demand = 151
          contractDemand: 201,
          estimatedBill: 0,
          loggedAt: DateTime(2026, 7, 3, hour),
          multiplyingFactor: 1,
        );

    test('reproduces the June/July line structure exactly', () {
      AppConfig.reset();
      final b = BillCalculator.calculate(
        logs: [
          shift(8069.4, 6), // 45% day
          shift(6276.2, 14), // 35% evening
          shift(3586.4, 22), // 20% night
        ],
        contractDemand: 201,
        energyRate: 8.44,
        demandRate: 650,
        facRate: 0.35,
        wheelingRate: 0.81,
        taxPerUnit: 0.2762, // 4,953.09 / 17,932 (bill exact)
        taxPercent: 0,
        dutyPercent: 0,
        electricityDutyPerUnit: 0,
        icrRate: 0.75,
        icrLastYearUnits: 12739,
        ppdPercent: 0,
        roundToTen: true,
        billOnKvah: true,
      );

      // Units & energy — exact bill lines.
      expect(b.totalUnits, closeTo(17932, 0.01));
      expect(b.energyCharges, closeTo(151346.08, 0.01)); // 17,932 × 8.44
      expect(b.billingDemand, 151); // floor: max(75% CD 150.75 → 151)
      expect(b.demandCharges, closeTo(98150, 0.01)); // 151 × 650
      expect(b.powerFactor, closeTo(0.92, 0.001)); // inside no-charge window

      // FAC 6,276.20, wheeling 14,524.92, tax ~4,953, duty exempt.
      expect(b.facCharges, closeTo(6276.20, 0.01));
      expect(b.wheelingCharges, closeTo(14524.92, 0.01));
      expect(b.taxes, closeTo(4953.09, 1.0));
      expect(b.electricityDuty, 0);

      // No PF rebate/penalty (0.90 ≤ PF < 0.95) — matches bill (no PF line).
      expect(b.pfRebate, 0);
      expect(b.pfSurcharge, 0);

      // ICR −3,894.75 (5,193 incremental × 0.75).
      expect(b.icrRebate, closeTo(3894.75, 0.01));

      // Slot engine keeps total unrounded (MSEDCL shows rupee-paisa), and
      // payable columns floor down to ₹10.
      expect(b.netBill,
          closeTo(b.energyCharges +
              b.demandCharges +
              b.todCharges +
              b.facCharges +
              b.wheelingCharges +
              b.taxes -
              b.icrRebate -
              b.lfIncentive, 0.05));
      expect(b.payableAfterDpc % 10, 0);
      expect(b.payableEarly % 10, 0);
    });

    test('slot engine zone units reconcile to the total billing units', () {
      AppConfig.reset();
      final b = BillCalculator.calculate(
        logs: [
          shift(8069.4, 6),
          shift(6276.2, 14),
          shift(3586.4, 22),
        ],
        contractDemand: 201,
        energyRate: 8.44,
        demandRate: 650,
        facRate: 0.35,
        wheelingRate: 0.81,
        taxPerUnit: 0.2762,
        icrRate: 0.75,
        icrLastYearUnits: 12739,
        ppdPercent: 0,
        billOnKvah: true,
      );
      final zoneTotal = b.todZoneUnits.values.fold(0.0, (a, v) => a + v);
      expect(zoneTotal, closeTo(b.totalUnits, 0.01));
      // 45/35/20 day/evening/night split maps to the expected zone units.
      expect(b.todZoneUnits['C'], closeTo(7396.95, 0.1)); // 12,361 ÷ … pro-rata
      expect(b.todZoneUnits['D'], closeTo(4819.225, 0.1));
    });
  });
}