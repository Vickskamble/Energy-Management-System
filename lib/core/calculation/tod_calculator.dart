import '../../domain/entities/energy_log_entity.dart';

/// Slot-wise ToD engine — replaces the old flat 4-multiplier average.
///
/// Each TOD-meter reading falls in an 8-hour window (06–14, 14–22, 22–06)
/// which covers two billing zones; the reading's units are split pro-rata by
/// the hours covered (e.g. 06–14 = 3h zone B + 5h zone C). Zone charges use
/// per-zone shares of the energy rate, exactly like the discom's zone
/// accumulators.
class TodCalculator {
  TodCalculator._();

  /// Zone shares per 8h window: (hours, {zone: fraction}).
  static const List<({int startHour, Map<String, double> shares})>
      _shiftSplits = [
    (startHour: 6, shares: {'B': 3 / 8, 'C': 5 / 8}),
    (startHour: 14, shares: {'C': 3 / 8, 'D': 5 / 8}),
    (startHour: 22, shares: {'D': 2 / 8, 'A': 6 / 8}),
  ];

  /// Result of the zone split: units and ₹ per zone + the net ToD charge.
  static TodZoneResult calculate({
    required List<EnergyLogEntity> logs,
    required Map<String, double> zoneShares,
    Map<String, double>? winterZoneShares,
    bool useWinter = false,
    required double energyRatePerUnit,
    bool onKvah = true,
  }) {
    final shares = useWinter && winterZoneShares != null
        ? winterZoneShares
        : zoneShares;
    final zoneUnits = <String, double>{};
    for (final log in logs) {
      final unit = (onKvah ? log.kvah : log.kwh) * log.multiplyingFactor;
      if (unit < 0) continue;
      final hour = log.loggedAt.hour;
      final split = _splitFor(hour);
      for (final entry in split.shares.entries) {
        zoneUnits[entry.key] =
            (zoneUnits[entry.key] ?? 0) + unit * entry.value;
      }
    }
    final zoneCharges = <String, double>{};
    var net = 0.0;
    for (final entry in shares.entries) {
      final units = zoneUnits[entry.key] ?? 0;
      // Zone rate (₹/u) = share of the energy rate, e.g. C = −15% of EC.
      final charge = units * entry.value * energyRatePerUnit;
      zoneCharges[entry.key] = charge;
      net += charge;
    }
    return TodZoneResult(
      zoneUnits: zoneUnits,
      zoneCharges: zoneCharges,
      netCharges: net,
    );
  }

  static ({int startHour, Map<String, double> shares}) _splitFor(int hour) {
    if (hour >= 6 && hour < 14) return _shiftSplits[0];
    if (hour >= 14 && hour < 22) return _shiftSplits[1];
    return _shiftSplits[2];
  }
}

class TodZoneResult {
  final Map<String, double> zoneUnits;
  final Map<String, double> zoneCharges;
  final double netCharges;

  const TodZoneResult({
    required this.zoneUnits,
    required this.zoneCharges,
    required this.netCharges,
  });
}