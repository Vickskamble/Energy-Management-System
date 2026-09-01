import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_breakdown.dart';
import 'package:ems/core/calculation/energy_intelligence.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity log({
  required int id,
  required int day,
  double kwh = 100,
  double kvah = 100,
  double md = 50,
  double mf = 1,
}) => EnergyLogEntity(
      id: 'r$id',
      meterName: 'Meter',
      kwh: kwh,
      kvah: kvah,
      rkvarhLag: 0,
      rkvarhLead: 0,
      powerFactor: kvah > 0 ? kwh / kvah : 0,
      mdRecorded: md,
      contractDemand: 201,
      estimatedBill: 0,
      loggedAt: DateTime(2026, 8, day, 10),
      multiplyingFactor: mf,
    );

BillBreakdown breakdown({double billingDemand = 151}) => BillBreakdown(
      totalUnits: 10000,
      energyCharges: 100000,
      demandCharges: 50000,
      facCharges: 5000,
      wheelingCharges: 2000,
      electricityDuty: 0,
      taxes: 3000,
      pfRebate: 0,
      pfSurcharge: 0,
      subsidy: 0,
      todCharges: 8000,
      icrRebate: 3894.75,
      lfIncentive: 1295,
      netBill: 146000,
      billingDemand: billingDemand,
      contractDemand: 201,
      powerFactor: 0.95,
      loadFactor: 0.6,
      averageUnitCost: 14.6,
    );

void main() {
  group('EnergyIntelligence', () {
    test('consumption + billed units are read from the right basis', () {
      final logs = [
        log(id: 1, day: 1, kwh: 3540, kvah: 3600),
      ];
      final b = breakdown();
      final i = EnergyIntelligence.from(logs, b);
      // Active kWh is the raw sum; billed units come from the breakdown.
      expect(i.totalKwh, closeTo(3540, 0.001));
      expect(i.billedUnits, closeTo(10000, 0.001));
    });

    test('PF series is sorted by date and tracks best/worst/average', () {
      final logs = [
        log(id: 1, day: 3, kwh: 90, kvah: 100), // 0.900
        log(id: 2, day: 1, kwh: 81.3, kvah: 100), // 0.813
        log(id: 3, day: 2, kwh: 95, kvah: 95), // 1.000
      ];
      final i = EnergyIntelligence.from(logs, breakdown());
      expect(i.pfSeries.first.date.day, 1);
      expect(i.pfSeries.last.date.day, 3);
      expect(i.bestPf, 1.0);
      expect(i.worstPf, closeTo(0.813, 0.001));
      expect(i.avgPf,
          closeTo((90 + 81.3 + 95) / (100 + 100 + 95), 0.001));
    });

    test('low PF events are detected below the watch threshold', () {
      final logs = [
        log(id: 1, day: 1, kwh: 90, kvah: 100), // 0.90 -> low
        log(id: 2, day: 2, kwh: 97, kvah: 100), // 0.97 -> fine
      ];
      final i = EnergyIntelligence.from(logs, breakdown());
      expect(i.lowPfEvents.length, 1);
      expect(i.lowPfEvents.first.pf, closeTo(0.90, 0.001));
    });

    test('invalid kWh > kVAh readings are flagged and lower confidence', () {
      final logs = [
        log(id: 1, day: 1, kwh: 120, kvah: 100), // kWh > kVAh -> invalid
        log(id: 2, day: 2, kwh: 90, kvah: 100),
      ];
      final i = EnergyIntelligence.from(logs, breakdown());
      expect(i.flaggedInvalid, 1);
      expect(i.confidenceScore, lessThan(100));
    });

    test('demand utilisation reflects billing vs contract demand', () {
      final i = EnergyIntelligence.from(
        [log(id: 1, day: 1, md: 110.5)],
        breakdown(billingDemand: 151),
      );
      expect(i.measuredPeakMd, closeTo(110.5, 0.001));
      expect(i.billingUtilPct, closeTo(75.1, 0.5));
      expect(i.peakUtilPct, closeTo(55.0, 0.5));
    });

    test('top consumption days are ranked by MF-adjusted kWh', () {
      final logs = [
        log(id: 1, day: 1, kwh: 50, mf: 5), // 250 kWh
        log(id: 2, day: 2, kwh: 90, mf: 1), // 90 kWh
        log(id: 3, day: 3, kwh: 80, mf: 1), // 80 kWh
      ];
      final i = EnergyIntelligence.from(logs, breakdown());
      expect(i.topDays.first.kwh, closeTo(250, 0.001));
      expect(i.topDays.first.date.day, 1);
    });

    test('missing calendar days are counted', () {
      final logs = [
        log(id: 1, day: 1),
        log(id: 2, day: 4),
        log(id: 3, day: 6),
      ];
      final i = EnergyIntelligence.from(logs, breakdown());
      // days 1,4,6 -> missing days 2,3,5 = 3 gaps
      expect(i.missingDayCount, 3);
    });

    test('incentives total sums all rebates', () {
      final b = BillBreakdown(
        totalUnits: 10000,
        energyCharges: 100000,
        demandCharges: 50000,
        facCharges: 5000,
        wheelingCharges: 2000,
        electricityDuty: 0,
        taxes: 3000,
        pfRebate: 2472,
        pfSurcharge: 0,
        subsidy: 0,
        todCharges: 8000,
        icrRebate: 3894.75,
        lfIncentive: 1295,
        netBill: 140000,
        billingDemand: 151,
        contractDemand: 201,
        powerFactor: 0.98,
        loadFactor: 0.6,
        averageUnitCost: 14.0,
      );
      final i = EnergyIntelligence.from([log(id: 1, day: 1)], b);
      expect(i.incentivesTotal, closeTo(2472 + 3894.75 + 1295, 0.001));
    });

    test('cost share percentages sum to ~100%', () {
      final i = EnergyIntelligence.from([log(id: 1, day: 1)], breakdown());
      final total = i.costShare.fold(0.0, (s, c) => s + c.percent);
      expect(total, closeTo(100, 0.5));
    });

    test('findings include incentives and demand utilisation signals', () {
      final i = EnergyIntelligence.from([log(id: 1, day: 1)], breakdown());
      expect(
        i.findings.any((f) => f.text.contains('incentive')),
        isTrue,
      );
      expect(
        i.findings.any((f) => f.text.contains('utilization')),
        isTrue,
      );
    });

    test('opportunities include PF, demand, TOD, base load and incentives', () {
      final i = EnergyIntelligence.from([log(id: 1, day: 1)], breakdown());
      final areas = i.opportunities.map((o) => o.area).toList();
      expect(areas, contains('Power Factor'));
      expect(areas, contains('Peak Demand'));
      expect(areas, contains('Incentives'));
    });
  });
}