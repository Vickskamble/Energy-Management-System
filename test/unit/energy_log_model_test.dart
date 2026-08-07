import 'package:ems/data/models/energy_log_model.dart';
import 'package:flutter_test/flutter_test.dart';

EnergyLogModel _log({
  required String meter,
  required DateTime at,
  required double kwh,
  double kvah = 0,
  double? currentKwh,
  double? currentKvah,
}) {
  return EnergyLogModel.create(
    meterName: meter,
    kwh: kwh,
    kvah: kvah,
    currentKwh: currentKwh,
    currentKvah: currentKvah,
    mdRecorded: 10,
    loggedAt: at,
  );
}

void main() {
  group('EnergyLogModel.hydrateActualReadings', () {
    test('reconstructs actual readings as running sum for legacy rows',
        () {
      final logs = [
        _log(meter: 'M1', at: DateTime(2026, 7, 1), kwh: 100),
        _log(meter: 'M1', at: DateTime(2026, 7, 2), kwh: 86),
        _log(meter: 'M1', at: DateTime(2026, 7, 3), kwh: 145),
      ];

      final hydrated = EnergyLogModel.hydrateActualReadings(logs);

      expect(hydrated[0].currentKwh, 100);
      expect(hydrated[1].currentKwh, 186);
      expect(hydrated[2].currentKwh, 331);
    });

    test('keeps stored actual readings untouched', () {
      final logs = [
        _log(
          meter: 'M1',
          at: DateTime(2026, 7, 1),
          kwh: 100,
          currentKwh: 57037,
          currentKvah: 59109,
        ),
        _log(meter: 'M1', at: DateTime(2026, 7, 2), kwh: 86),
      ];

      final hydrated = EnergyLogModel.hydrateActualReadings(logs);

      expect(hydrated[0].currentKwh, 57037);
      expect(hydrated[0].currentKvah, 59109);
      // Legacy row after a stored row: chain continues from stored value.
      expect(hydrated[1].currentKwh, 57123);
    });

    test('running sums are independent per meter', () {
      final logs = [
        _log(meter: 'M1', at: DateTime(2026, 7, 1), kwh: 100),
        _log(meter: 'M2', at: DateTime(2026, 7, 1), kwh: 500),
        _log(meter: 'M1', at: DateTime(2026, 7, 2), kwh: 50),
        _log(meter: 'M2', at: DateTime(2026, 7, 2), kwh: 25),
      ];

      final hydrated = EnergyLogModel.hydrateActualReadings(logs);

      expect(hydrated[0].currentKwh, 100);
      expect(hydrated[1].currentKwh, 500);
      expect(hydrated[2].currentKwh, 150);
      expect(hydrated[3].currentKwh, 525);
    });

    test('sorts by date before accumulating', () {
      final logs = [
        _log(meter: 'M1', at: DateTime(2026, 7, 10), kwh: 50),
        _log(meter: 'M1', at: DateTime(2026, 7, 1), kwh: 100),
      ];

      final hydrated = EnergyLogModel.hydrateActualReadings(logs);

      expect(hydrated[0].currentKwh, 100);
      expect(hydrated[1].currentKwh, 150);
    });

    test('empty list returns empty list', () {
      expect(EnergyLogModel.hydrateActualReadings([]), isEmpty);
    });
  });
}
