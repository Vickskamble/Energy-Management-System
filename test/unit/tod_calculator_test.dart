import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/tod_calculator.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required String name,
  required double kwh,
  required double kvah,
  required int hour,
  DateTime? at,
}) {
  return EnergyLogEntity(
    id: name,
    meterName: 'Meter-01',
    kwh: kwh,
    kvah: kvah,
    rkvarhLag: 0,
    rkvarhLead: 0,
    powerFactor: kwh > 0 && kvah > 0 ? kwh / kvah : 0,
    mdRecorded: 30,
    contractDemand: 400,
    estimatedBill: 0,
    loggedAt: at ?? DateTime(2026, 7, 3, hour),
    multiplyingFactor: 1,
  );
}

void main() {
  group('TodCalculator slot engine', () {
    const shares = {'A': 0.0, 'B': 0.0, 'C': -0.15, 'D': 0.25};

    test('splits each 8h window pro-rata across its two zones '
        '(shift-structured day)', () {
      final result = TodCalculator.calculate(
        logs: [
          _log(name: 'day', kwh: 92, kvah: 100, hour: 6),
          _log(name: 'eve', kwh: 92, kvah: 100, hour: 14),
          _log(name: 'night', kwh: 92, kvah: 100, hour: 22),
        ],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
      );
      // 06–14 → B 3/8 + C 5/8; 14–22 → C 3/8 + D 5/8; 22–06 → D 2/8 + A 6/8
      expect(result.zoneUnits['A'], closeTo(75, 0.001));
      expect(result.zoneUnits['B'], closeTo(37.5, 0.001));
      expect(result.zoneUnits['C'], closeTo(100, 0.001));
      expect(result.zoneUnits['D'], closeTo(87.5, 0.001));
    });

    test('daily-totalizer day (single reading) spreads across zones '
        'by wall-clock duration', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'one', kwh: 92, kvah: 100, hour: 0)],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
      );
      // A 6h, B 3h, C 8h, D 7h of 24h — never a dump into one zone.
      expect(result.zoneUnits['A'], closeTo(25, 0.001));
      expect(result.zoneUnits['B'], closeTo(12.5, 0.001));
      expect(result.zoneUnits['C'], closeTo(100 / 3, 0.001));
      expect(result.zoneUnits['D'], closeTo(29.1667, 0.001));
    });

    test('zone charges = units × (share × energy rate)', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 92, kvah: 100, hour: 6)],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
      );
      // single reading = totalizer: C 33.333 × (−0.15 × 8.44) + D 29.167 ×
      // (0.25 × 8.44) = −42.2 + 61.54
      expect(result.netCharges, closeTo(19.34, 0.01));
    });

    test('winter deepens the solar-window rebate only', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 92, kvah: 100, hour: 6)],
        zoneShares: shares,
        winterZoneShares: const {'A': 0.0, 'B': 0.0, 'C': -0.25, 'D': 0.25},
        useWinter: true,
        energyRatePerUnit: 8.44,
      );
      // single reading = totalizer: C 33.333 × (−0.25 × 8.44) + D 29.167 ×
      // (0.25 × 8.44) = −70.33 + 61.54
      expect(result.netCharges, closeTo(-8.79, 0.01));
    });

    test('bills kWh when the kVAh toggle is off', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 100, kvah: 200, hour: 6)],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
        onKvah: false,
      );
      // C fraction of the kWh (100, not 200) via duration spread
      expect(result.zoneUnits['C'], closeTo(100 / 3, 0.001));
    });

    test('day buckets spread shift units evenly for totalizer days and '
        'keep window attribution for shift-structured days', () {
      final buckets = TodCalculator.days(
        logs: [
          _log(name: 'totalizer', kwh: 92, kvah: 100, hour: 0,
              at: DateTime(2026, 7, 2, 0)),
          _log(name: 'day', kwh: 103.5, kvah: 112.5, hour: 6),
          _log(name: 'eve', kwh: 103.5, kvah: 112.5, hour: 14),
          _log(name: 'night', kwh: 103.5, kvah: 112.5, hour: 22),
        ],
      );
      expect(buckets, hasLength(2));
      final totalizer = buckets.first;
      expect(totalizer.shiftUnits[0], closeTo(100 / 3, 0.001));
      expect(totalizer.shiftUnits[1], closeTo(100 / 3, 0.001));
      expect(totalizer.shiftUnits[2], closeTo(100 / 3, 0.001));
      final structured = buckets.last;
      expect(structured.shiftUnits[0], closeTo(112.5, 0.001));
      expect(structured.shiftUnits[1], closeTo(112.5, 0.001));
      expect(structured.shiftUnits[2], closeTo(112.5, 0.001));
    });
  });
}