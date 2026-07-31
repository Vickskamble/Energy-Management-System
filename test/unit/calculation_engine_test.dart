import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/utils/calculation_engine.dart';

void main() {
  group('calculatePowerFactor', () {
    test('returns correct PF for valid inputs', () {
      expect(
        CalculationEngine.calculatePowerFactor(100, 125),
        closeTo(0.800, 0.001),
      );
    });

    test('clamps PF to 1.000 maximum', () {
      expect(
        CalculationEngine.calculatePowerFactor(150, 100),
        closeTo(1.000, 0.001),
      );
    });

    test('returns 0 when kwh is 0', () {
      expect(CalculationEngine.calculatePowerFactor(0, 100), 0.000);
    });

    test('returns 0 when kvah is 0', () {
      expect(CalculationEngine.calculatePowerFactor(100, 0), 0.000);
    });

    test('returns 0 when both are 0', () {
      expect(CalculationEngine.calculatePowerFactor(0, 0), 0.000);
    });

    test('rounds to 3 decimal places', () {
      final pf = CalculationEngine.calculatePowerFactor(1, 3);
      expect(pf.toStringAsFixed(3), '0.333');
    });
  });

  group('calculateEstimatedBill', () {
    test('calculates bill using new tariff: units × MF × rate', () {
      final bill = CalculationEngine.calculateEstimatedBill(kwh: 1000);
      // 1000 × 5 (MF) × 8.68 = 43,400
      expect(bill, closeTo(43400, 1));
    });

    test('bill is same regardless of PF (no penalty in per-reading calc)', () {
      final bill = CalculationEngine.calculateEstimatedBill(kwh: 500);
      // 500 × 5 × 8.68 = 21,700
      expect(bill, closeTo(21700, 1));
    });
  });

  group('isNearContractDemandBreach', () {
    test('returns true when md >= threshold', () {
      expect(CalculationEngine.isNearContractDemandBreach(380), true);
    });

    test('returns false when md < threshold', () {
      expect(CalculationEngine.isNearContractDemandBreach(300), false);
    });
  });

  group('hasReactivePenaltyRisk', () {
    test('returns true when PF < 0.95', () {
      expect(CalculationEngine.hasReactivePenaltyRisk(0.85), true);
    });

    test('returns false when PF >= 0.95', () {
      expect(CalculationEngine.hasReactivePenaltyRisk(0.97), false);
    });
  });

  group('formatInr', () {
    test('formats basic amount', () {
      expect(CalculationEngine.formatInr(50000), '₹50000');
    });

    test('formats lakhs', () {
      expect(CalculationEngine.formatInr(250000), '₹2.50 L');
    });

    test('formats crores', () {
      expect(CalculationEngine.formatInr(15000000), '₹1.50 Cr');
    });
  });
}
