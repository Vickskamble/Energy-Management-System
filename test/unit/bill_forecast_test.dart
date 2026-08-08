import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/calculation/bill_forecast.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity _log({
  required double kwh,
  required double kvah,
  required double md,
  required DateTime at,
}) {
  return EnergyLogEntity(
    id: 'log-$kwh-$kvah-$md-${at.millisecondsSinceEpoch}',
    meterName: 'Meter-01',
    kwh: kwh,
    kvah: kvah,
    rkvarhLag: 0,
    rkvarhLead: 0,
    powerFactor: kwh > 0 && kvah > 0 ? (kwh / kvah).clamp(0.0, 1.0) : 0,
    mdRecorded: md,
    contractDemand: 400,
    estimatedBill: 0,
    loggedAt: at,
    multiplyingFactor: 5,
  );
}

void main() {
  final januaryLogs = [
    _log(kwh: 200, kvah: 250, md: 300, at: DateTime(2026, 1, 2)),
    _log(kwh: 200, kvah: 250, md: 300, at: DateTime(2026, 1, 9)),
  ];

  group('BillForecastCalculator.calculate', () {
    test('returns null when there are no logs', () {
      expect(
        BillForecastCalculator.calculate(
          monthLogs: const [],
          referenceDate: DateTime(2026, 1, 10),
        ),
        isNull,
      );
    });

    test('projects units linearly for the whole month', () {
      final forecast = BillForecastCalculator.calculate(
        monthLogs: januaryLogs,
        referenceDate: DateTime(2026, 1, 10),
      )!;

      expect(forecast.daysElapsed, 10);
      expect(forecast.daysInMonth, 31);
      // (250 kVAh × 5 MF) × 2 logs = 2500 units, scaled 31/10
      expect(forecast.projectedUnits, closeTo(7750, 0.01));
    });

    test('projects a positive bill consistent with the breakdown', () {
      final forecast = BillForecastCalculator.calculate(
        monthLogs: januaryLogs,
        referenceDate: DateTime(2026, 1, 10),
      )!;

      expect(forecast.projectedBill, greaterThan(0));
      expect(forecast.dailyAverageBill, greaterThan(0));
      // 7750 kVAh units: energy 65410 + demand 975000 + FAC 2325 + wheeling
      // 6277.5 + duty 2131.25 + tax 2162.25 + surcharge 52020.5 − rebate − 0
      expect(forecast.projectedBill, closeTo(1105326.50, 0.01));
    });

    test('scales by the number of days in the reference month', () {
      final forecast = BillForecastCalculator.calculate(
        monthLogs: [
          _log(kwh: 100, kvah: 120, md: 200, at: DateTime(2026, 2, 1)),
        ],
        referenceDate: DateTime(2026, 2, 15),
      )!;

      expect(forecast.daysElapsed, 15);
      expect(forecast.daysInMonth, 28);
      // (120 kVAh × 5 MF) = 600 units, scaled 28/15
      expect(forecast.projectedUnits, closeTo(1120, 0.01));
    });
  });
}
