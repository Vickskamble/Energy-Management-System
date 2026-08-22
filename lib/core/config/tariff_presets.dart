/// MERC Maharashtra tariff presets — official rates from:
///   - MYT Order Case 217/2024 (FY 2025-26)
///   - Tariff Order Case 75/2025 (FY 2026-27, post-remand proceedings)
/// Presets are auto-loaded into [AppConfig] when the user picks a category
/// and tariff year in Settings → Billing. Individual rates stay editable.
library;

/// Consumer category — determines which charge structure applies.
enum TariffCategory {
  htIndustrial('ht_industrial', 'HT-I A Industry'),
  htIndustrialSeasonal(
      'ht_industrial_seasonal', 'HT-I B Seasonal Industry'),
  htCommercial('ht_commercial', 'HT-II Commercial'),
  ltResidential('lt_residential', 'LT-I Residential'),
  ltIndustrial('lt_industrial', 'LT-V Industry (≤20 kW)');

  final String id;
  final String label;

  const TariffCategory(this.id, this.label);

  static TariffCategory fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return TariffCategory.htIndustrial;
  }
}

/// Tariff year — official rates differ between FY 2025-26 and FY 2026-27
/// (FY 26-27 = Case 75/2025 addendum).
enum TariffVersion {
  fy2526('fy2526', 'FY 2025-26'),
  fy2627('fy2627', 'FY 2026-27');

  final String id;
  final String label;

  const TariffVersion(this.id, this.label);

  static TariffVersion fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return TariffVersion.fy2627;
  }
}

/// One energy-consumption slab: rate applies to the units above the
/// previous slab's limit and up to [upTo] units (double.infinity = no cap).
class EnergySlab {
  final double upTo;
  final double rate;

  const EnergySlab({required this.upTo, required this.rate});
}

/// Complete official charge structure for one category × year.
class TariffPreset {
  final TariffCategory category;
  final TariffVersion version;
  final double energyRate;
  final List<EnergySlab> slabs;
  final double demandRate;
  final double wheelingRate;

  /// Electricity duty as % of energy charges (0 = exempt — HT categories).
  final double dutyPercent;

  /// Fixed monthly charge in ₹ (0 when demand charges cover it — HT).
  final double fixedCharge;

  /// Suggested sanctioned/contract demand in kVA for this category.
  final double defaultContractDemand;

  /// Slot-wise ToD engine — share of the energy rate (₹/u) charged per
  /// zone A/B/C/D (6 h each). C = solar-window rebate, D = peak surcharge
  /// (Case 75/2025). Defaults follow AppConstants.todZoneShares.
  final Map<String, double> todZoneShares;

  /// Winter (Oct–Mar) zone shares — C rebate deepens to −25%.
  final Map<String, double> todZoneSharesWinter;

  const TariffPreset({
    required this.category,
    required this.version,
    required this.energyRate,
    this.slabs = const [],
    required this.demandRate,
    required this.wheelingRate,
    required this.dutyPercent,
    this.fixedCharge = 0,
    required this.defaultContractDemand,
    this.todZoneShares = const {'A': 0.0, 'B': 0.0, 'C': -0.15, 'D': 0.25},
    this.todZoneSharesWinter =
        const {'A': 0.0, 'B': 0.0, 'C': -0.25, 'D': 0.25},
  });

  /// Energy charge rate used when the user does not have a stored override.
  double get effectiveEnergyRate => energyRate;

  bool get isSlabBased => slabs.isNotEmpty;
}

class TariffPresets {
  TariffPresets._();

  static const ltSlabs = [
    EnergySlab(upTo: 100, rate: 3.96),
    EnergySlab(upTo: 300, rate: 10.80),
    EnergySlab(upTo: 500, rate: 15.03),
    EnergySlab(upTo: double.infinity, rate: 17.53),
  ];

  static const List<double> defaultTod = [1.0, 1.0, 0.85, 1.20];

  static TariffPreset presetFor(
    TariffCategory category,
    TariffVersion version,
  ) {
    const ltFixed = 130.0;
    const ltIndFixed = 650.0;
    const ltWheeling = 1.60;
    const ltDuty = 16.0;

    switch (category) {
      case TariffCategory.htIndustrial:
        return TariffPreset(
          category: category,
          version: version,
          energyRate: version == TariffVersion.fy2526 ? 8.98 : 8.68,
          demandRate: version == TariffVersion.fy2526 ? 549.0 : 600.0,
          wheelingRate: version == TariffVersion.fy2526 ? 0.81 : 0.74,
          dutyPercent: 0,
          defaultContractDemand: 201.0,
        );
      case TariffCategory.htIndustrialSeasonal:
        return TariffPreset(
          category: category,
          version: version,
          energyRate: version == TariffVersion.fy2526 ? 8.70 : 8.47,
          demandRate: version == TariffVersion.fy2526 ? 549.0 : 650.0,
          wheelingRate: version == TariffVersion.fy2526 ? 0.81 : 0.81,
          dutyPercent: 0,
          defaultContractDemand: 790.0,
        );
      case TariffCategory.htCommercial:
        return TariffPreset(
          category: category,
          version: version,
          energyRate: version == TariffVersion.fy2526 ? 14.08 : 14.03,
          demandRate: version == TariffVersion.fy2526 ? 549.0 : 600.0,
          wheelingRate: version == TariffVersion.fy2526 ? 0.81 : 0.74,
          dutyPercent: 0,
          defaultContractDemand: 100.0,
        );
      case TariffCategory.ltResidential:
        return TariffPreset(
          category: category,
          version: version,
          energyRate: 3.96,
          slabs: ltSlabs,
          demandRate: 0,
          wheelingRate: ltWheeling,
          dutyPercent: ltDuty,
          fixedCharge: ltFixed,
          defaultContractDemand: 10.0,
          todZoneShares: const {'A': 0.0, 'B': 0.0, 'C': -0.20, 'D': 0.20},
          todZoneSharesWinter:
              const {'A': 0.0, 'B': 0.0, 'C': -0.25, 'D': 0.20},
        );
      case TariffCategory.ltIndustrial:
        return TariffPreset(
          category: category,
          version: version,
          energyRate: 6.26,
          demandRate: 0,
          wheelingRate: ltWheeling,
          dutyPercent: ltDuty,
          fixedCharge: ltIndFixed,
          defaultContractDemand: 20.0,
          todZoneShares: const {'A': 0.0, 'B': 0.0, 'C': -0.20, 'D': 0.20},
          todZoneSharesWinter:
              const {'A': 0.0, 'B': 0.0, 'C': -0.25, 'D': 0.20},
        );
    }
  }

  static TariffPreset defaultPreset() =>
      presetFor(TariffCategory.htIndustrial, TariffVersion.fy2627);
}
