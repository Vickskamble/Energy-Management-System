import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/tod_calculator.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required String name,
  required double kwh,
  required double kvah,
  required int hour,
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
    loggedAt: DateTime(2026, 7, 3, hour),
    multiplyingFactor: 1,
  );
}

void main() {
  group('TodCalculator slot engine', () {
    const shares = {'A': 0.0, 'B': 0.0, 'C': -0.15, 'D': 0.25};

    test('splits each 8h window pro-rata across its two zones', () {
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

    test('zone charges = units × (share × energy rate)', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 92, kvah: 100, hour: 6)],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
      );
      // C 62.5 × (−0.15 × 8.44 = −1.266) + B 37.5 × 0
      expect(result.netCharges, closeTo(-79.125, 0.001));
    });

    test('winter deepens the solar-window rebate only', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 92, kvah: 100, hour: 6)],
        zoneShares: shares,
        winterZoneShares: const {'A': 0.0, 'B': 0.0, 'C': -0.25, 'D': 0.25},
        useWinter: true,
        energyRatePerUnit: 8.44,
      );
      // C 62.5 × (−0.25 × 8.44 = −2.11) = −131.875
      expect(result.netCharges, closeTo(-131.875, 0.001));
    });

    test('bills kWh when the kVAh toggle is off', () {
      final result = TodCalculator.calculate(
        logs: [_log(name: 'day', kwh: 100, kvah: 200, hour: 6)],
        zoneShares: shares,
        energyRatePerUnit: 8.44,
        onKvah: false,
      );
      // C fraction of the kWh (100, not 200)
      expect(result.zoneUnits['C'], closeTo(62.5, 0.001));
    });
  });
}