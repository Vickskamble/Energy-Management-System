import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/config/app_config.dart';
import 'package:ems/core/config/tariff_presets.dart';
import 'package:ems/core/calculation/bill_calculator.dart';
import 'package:ems/core/calculation/energy_calculator.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

void main() {
  group('TariffPresets', () {
    test('FY 26-27 HT-I industry rates match the official order', () {
      final p = TariffPresets.presetFor(
        TariffCategory.htIndustrial,
        TariffVersion.fy2627,
      );
      expect(p.energyRate, 8.68);
      expect(p.demandRate, 600.0);
      expect(p.wheelingRate, 0.74);
      expect(p.dutyPercent, 0); // HT exempt
      expect(p.fixedCharge, 0);
      expect(p.isSlabBased, isFalse);
    });

    test('FY 25-26 HT-I industry uses the previous year rates', () {
      final p = TariffPresets.presetFor(
        TariffCategory.htIndustrial,
        TariffVersion.fy2526,
      );
      expect(p.energyRate, 8.98);
      expect(p.demandRate, 549.0);
      expect(p.wheelingRate, 0.81);
    });

    test('LT-I residential is slab based with 16% duty and fixed charge', () {
      final p = TariffPresets.presetFor(
        TariffCategory.ltResidential,
        TariffVersion.fy2627,
      );
      expect(p.isSlabBased, isTrue);
      expect(p.slabs.length, 4);
      expect(p.slabs.last.rate, 17.53);
      expect(p.dutyPercent, 16);
      expect(p.fixedCharge, 130.0);
      expect(p.demandRate, 0);
    });

    test('preset applies into AppConfig', () {
      AppConfig.applyTariffPreset(
        TariffCategory.ltResidential,
        TariffVersion.fy2627,
      );
      expect(AppConfig.tariffCategory, TariffCategory.ltResidential);
      expect(AppConfig.tariffVersion, TariffVersion.fy2627);
      expect(AppConfig.dutyPercent, 16);
      expect(AppConfig.fixedCharge, 130.0);
      expect(AppConfig.contractDemandKva, 10.0);
      AppConfig.applyTariffPreset(
        TariffCategory.htIndustrial,
        TariffVersion.fy2627,
      );
      expect(AppConfig.dutyPercent, 0);
      expect(AppConfig.fixedCharge, 0);
    });
  });

  group('EnergyCalculator.calculateSlabEnergy', () {
    const slabs = [
      EnergySlab(upTo: 100, rate: 3.96),
      EnergySlab(upTo: 300, rate: 10.80),
      EnergySlab(upTo: 500, rate: 15.03),
      EnergySlab(upTo: double.infinity, rate: 17.53),
    ];

    test('all units inside first slab', () {
      expect(
        EnergyCalculator.calculateSlabEnergy(80, slabs),
        closeTo(80 * 3.96, 0.01),
      );
    });

    test('units crossing two slabs', () {
      // 100 × 3.96 + 50 × 10.80
      expect(
        EnergyCalculator.calculateSlabEnergy(150, slabs),
        closeTo(100 * 3.96 + 50 * 10.80, 0.01),
      );
    });

    test('units beyond the last cap use the final rate', () {
      // 100×3.96 + 200×10.80 + 200×15.03 + 100×17.53
      expect(
        EnergyCalculator.calculateSlabEnergy(600, slabs),
        closeTo(
          100 * 3.96 + 200 * 10.80 + 200 * 15.03 + 100 * 17.53,
          0.01,
        ),
      );
    });

    test('empty slabs yield zero', () {
      expect(EnergyCalculator.calculateSlabEnergy(100, const []), 0);
    });
  });

  group('BillCalculator duty model', () {
    EnergyLogEntity log(double kwh, double kvah, double md) => EnergyLogEntity(
          id: 'm1',
          meterName: 'Meter-01',
          kwh: kwh,
          kvah: kvah,
          rkvarhLag: 0,
          rkvarhLead: 0,
          powerFactor: 0.95,
          mdRecorded: md,
          contractDemand: 201,
          estimatedBill: 0,
          loggedAt: DateTime(2026, 7, 15),
        );

    test('HT duty exempt (0%) produces no duty', () {
      AppConfig.applyTariffPreset(
        TariffCategory.htIndustrial,
        TariffVersion.fy2627,
      );
      final b = BillCalculator.calculate(logs: [log(100, 110, 50)]);
      expect(b.electricityDuty, 0);
    });

    test('LT 16% duty is a percentage of energy charges', () {
      AppConfig.applyTariffPreset(
        TariffCategory.ltResidential,
        TariffVersion.fy2627,
      );
      final b = BillCalculator.calculate(logs: [log(100, 110, 50)]);
      expect(b.electricityDuty, closeTo(b.energyCharges * 0.16, 0.01));
      expect(b.fixedCharge, 130.0);
      expect(b.netBill, greaterThan(0));
    });

    test('LT slab billing beats flat rate for high consumers', () {
      AppConfig.applyTariffPreset(
        TariffCategory.ltResidential,
        TariffVersion.fy2627,
      );
      final b = BillCalculator.calculate(logs: [log(1000, 1000, 50)]);
      final flat = 1000 * 3.96;
      expect(b.energyCharges, greaterThan(flat));
    });
  });
}
