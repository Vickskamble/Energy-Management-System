import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';
import 'tariff_presets.dart';

/// Runtime-configurable tariff settings (persisted locally).
/// Falls back to [AppConstants] defaults when nothing is stored.
class AppConfig {
  AppConfig._();

  /// Current app version, shown in Settings > System. Keep in sync with pubspec.
  static const String appVersion = '1.1.12';

  static double _tariffPerUnit = AppConstants.tariffPerUnit;
  static double _demandChargePerKva = AppConstants.demandChargePerKva;
  static double _facRatePerUnit = AppConstants.facRatePerUnit;
  static double _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
  static double _electricityDutyPerUnit = AppConstants.electricityDutyPerUnit;
  static double _taxPerUnit = AppConstants.taxPerUnit;
  static double _subsidyPercent = AppConstants.subsidyPercent;
  static double _contractDemandKva = AppConstants.defaultContractDemandKva;
  static List<double> _precedingDemandKva = List.filled(11, 0);
  static double _regionSubsidyAmount = 0.0;
  static double _rebateSection106 = 0.0;

  /// Selected MERC tariff category (HT-I Industry by default).
  static TariffCategory tariffCategory = TariffCategory.htIndustrial;

  /// Selected tariff year (FY 2026-27 by default).
  static TariffVersion tariffVersion = TariffVersion.fy2627;

  /// Electricity duty as % of energy charges (0 = exempt — HT categories).
  /// When > 0 the flat [electricityDutyPerUnit] charge is ignored.
  static double _dutyPercent = 0.0;

  /// Fixed monthly charge in ₹ (LT categories; 0 for HT).
  static double _fixedCharge = 0.0;

  /// Official energy-consumption slabs for LT categories (empty for HT —
  /// flat rate). Applied automatically when a slab-based preset is active.
  static List<EnergySlab> _energySlabs = const [];

  /// TOD multipliers: index 0 = Zone A (00-06), 1 = Zone B (06-18),
  /// 2 = Zone C (09-18), 3 = Zone D (17-24).  Multiplier 1.0 = no change.
  static List<double> _todMultipliers = [1.0, 1.0, 1.0, 1.0];

  /// Effective energy tariff per unit (₹/kWh) — editable via Settings.
  static double get tariffPerUnit => _tariffPerUnit;
  static set tariffPerUnit(double value) {
    if (value > 0) _tariffPerUnit = value;
  }

  /// Demand charge per kVA (₹).
  static double get demandChargePerKva => _demandChargePerKva;
  static set demandChargePerKva(double value) {
    if (value >= 0) _demandChargePerKva = value;
  }

  /// Fuel Adjustment Charge per unit (₹).
  static double get facRatePerUnit => _facRatePerUnit;
  static set facRatePerUnit(double value) {
    if (value >= 0) _facRatePerUnit = value;
  }

  /// Wheeling charge per unit (₹).
  static double get wheelingChargePerUnit => _wheelingChargePerUnit;
  static set wheelingChargePerUnit(double value) {
    if (value >= 0) _wheelingChargePerUnit = value;
  }

  /// Electricity duty per unit (₹) — flat per-unit charge, NOT percentage.
  static double get electricityDutyPerUnit => _electricityDutyPerUnit;
  static set electricityDutyPerUnit(double value) {
    if (value >= 0) _electricityDutyPerUnit = value;
  }

  /// Tax per unit (₹) — flat per-unit charge, NOT percentage.
  static double get taxPerUnit => _taxPerUnit;
  static set taxPerUnit(double value) {
    if (value >= 0) _taxPerUnit = value;
  }

  /// Subsidy percentage (0 when none).
  static double get subsidyPercent => _subsidyPercent;
  static set subsidyPercent(double value) {
    if (value >= 0) _subsidyPercent = value;
  }

  /// Contract (MD) demand in kVA — the meter's sanctioned demand. The
  /// billing demand is the max of the recorded MD and the 11-month ratchet
  /// peak; 75% of this value is only a reference line on charts/savings
  /// logic and is never part of the bill.
  static double get contractDemandKva => _contractDemandKva;
  static set contractDemandKva(double value) {
    if (value > 0) _contractDemandKva = value;
  }

  /// User-provided recorded demand (kVA) of the preceding 11 months —
  /// used as the billing-demand ratchet window (11-month preceding high).
  /// Index 0 = oldest, index 10 = most recent preceding month.
  static List<double> get precedingDemandKva =>
      List.unmodifiable(_precedingDemandKva);
  static set precedingDemandKva(List<double> value) {
    if (value.isEmpty) return;
    final padded = List<double>.of(value);
    while (padded.length < 11) {
      padded.insert(0, 0);
    }
    _precedingDemandKva = padded.take(11).toList();
  }

  /// Auto-computed — 75% of contract MD, the billing demand floor
  /// (displayed in Settings, not editable).
  static double get billingDemandFloorKva =>
      _contractDemandKva * AppConstants.billingDemandFloorPercent;

  /// Region subsidy flat amount deduction (₹).
  static double get regionSubsidyAmount => _regionSubsidyAmount;
  static set regionSubsidyAmount(double value) {
    if (value >= 0) _regionSubsidyAmount = value;
  }

  /// Rebate U/s 106 flat amount deduction (₹).
  static double get rebateSection106 => _rebateSection106;
  static set rebateSection106(double value) {
    if (value >= 0) _rebateSection106 = value;
  }

  /// TOD multipliers [ZoneA, ZoneB, ZoneC, ZoneD].
  static List<double> get todMultipliers => List.unmodifiable(_todMultipliers);
  static set todMultipliers(List<double> value) {
    if (value.length == 4) _todMultipliers = value;
  }

  /// Electricity duty as % of energy charges (0 = exempt).
  static double get dutyPercent => _dutyPercent;
  static set dutyPercent(double value) {
    if (value >= 0) _dutyPercent = value;
  }

  /// Fixed monthly charge in ₹ (0 = none).
  static double get fixedCharge => _fixedCharge;
  static set fixedCharge(double value) {
    if (value >= 0) _fixedCharge = value;
  }

  /// Active energy-consumption slabs (empty = flat rate).
  static List<EnergySlab> get energySlabs => List.unmodifiable(_energySlabs);
  static set energySlabs(List<EnergySlab> value) => _energySlabs = value;

  /// Tax as % of energy charges (0 = use legacy flat per-unit [taxPerUnit]).
  static double _taxPercent = AppConstants.taxPercent;
  static double get taxPercent => _taxPercent;
  static set taxPercent(double value) {
    if (value >= 0) _taxPercent = value;
  }

  /// ICR rebate — ₹ per unit on incremental consumption (≥10% growth vs
  /// same month last year). 0 = off.
  static double _icrRatePerUnit = AppConstants.icrRatePerUnit;
  static double get icrRatePerUnit => _icrRatePerUnit;
  static set icrRatePerUnit(double value) {
    if (value >= 0) _icrRatePerUnit = value;
  }

  /// Same month last year's consumption (kVAh) — ICR growth baseline.
  static double _icrLastYearUnits = 0.0;
  static double get icrLastYearUnits => _icrLastYearUnits;
  static set icrLastYearUnits(double value) {
    if (value >= 0) _icrLastYearUnits = value;
  }

  /// Load Factor incentive — % of (energy + demand) charges. 0 = off.
  static double _lfIncentivePercent = AppConstants.lfIncentivePercent;
  static double get lfIncentivePercent => _lfIncentivePercent;
  static set lfIncentivePercent(double value) {
    if (value >= 0) _lfIncentivePercent = value;
  }

  /// Prompt Payment Discount — % of the bill. 0 = off.
  static double _ppdPercent = AppConstants.ppdPercent;
  static double get ppdPercent => _ppdPercent;
  static set ppdPercent(double value) {
    if (value >= 0) _ppdPercent = value;
  }

  /// Bulk consumption rebate — % of energy charges. 0 = off.
  static double _bulkRebatePercent = AppConstants.bulkRebatePercent;
  static double get bulkRebatePercent => _bulkRebatePercent;
  static set bulkRebatePercent(double value) {
    if (value >= 0) _bulkRebatePercent = value;
  }

  /// Arrears / DPC flat amount in ₹ added to the bill.
  static double _arrearsDpcAmount = AppConstants.arrearsDpcAmount;
  static double get arrearsDpcAmount => _arrearsDpcAmount;
  static set arrearsDpcAmount(double value) {
    if (value >= 0) _arrearsDpcAmount = value;
  }

  /// Round the final bill to the nearest ₹10.
  static bool roundToTen = AppConstants.roundToTen;

  /// Bill on kVAh (official) or kWh when off.
  static bool billOnKvah = AppConstants.billOnKvah;

  /// Per-month FAC rates (₹/unit) — keyed "YYYY-MM". Falls back to
  /// [facRatePerUnit] for months without an explicit rate.
  static Map<String, double> _facRatesByMonth = {};
  static Map<String, double> get facRatesByMonth =>
      Map.unmodifiable(_facRatesByMonth);
  static set facRatesByMonth(Map<String, double> value) => _facRatesByMonth = value;

  /// FAC rate for a "YYYY-MM" [monthKey], or the default when not set.
  static double facRateForMonth(String monthKey) =>
      _facRatesByMonth[monthKey] ?? _facRatePerUnit;

  /// Loads the official MERC rates for [category] × [version] into every
  /// tariff field (energy, demand, wheeling, duty, TOD, fixed charge,
  /// contract demand). Returns the applied preset so the caller can sync
  /// its UI. Individual fields remain editable after the preset is applied.
  static TariffPreset applyTariffPreset(
    TariffCategory category,
    TariffVersion version,
  ) {
    final preset = TariffPresets.presetFor(category, version);
    tariffCategory = category;
    tariffVersion = version;
    _tariffPerUnit = preset.energyRate;
    _demandChargePerKva = preset.demandRate;
    _wheelingChargePerUnit = preset.wheelingRate;
    _dutyPercent = preset.dutyPercent;
    // HT categories are exempt (0%); LT use the % model — either way the
    // legacy flat per-unit duty must not leak into preset-driven bills.
    _electricityDutyPerUnit = 0.0;
    _fixedCharge = preset.fixedCharge;
    _energySlabs = List.of(preset.slabs);
    _todMultipliers = List.of(preset.todMultipliers);
    _contractDemandKva = preset.defaultContractDemand;
    return preset;
  }

  static void reset() {
    _tariffPerUnit = AppConstants.tariffPerUnit;
    _demandChargePerKva = AppConstants.demandChargePerKva;
    _facRatePerUnit = AppConstants.facRatePerUnit;
    _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
    _electricityDutyPerUnit = AppConstants.electricityDutyPerUnit;
    _taxPerUnit = AppConstants.taxPerUnit;
    _subsidyPercent = AppConstants.subsidyPercent;
    _contractDemandKva = AppConstants.defaultContractDemandKva;
    _precedingDemandKva = List.filled(11, 0);
    _regionSubsidyAmount = 0.0;
    _rebateSection106 = 0.0;
    _todMultipliers = [1.0, 1.0, 1.0, 1.0];
    _dutyPercent = 0.0;
    _fixedCharge = 0.0;
    _energySlabs = const [];
    _taxPercent = AppConstants.taxPercent;
    _icrRatePerUnit = AppConstants.icrRatePerUnit;
    _icrLastYearUnits = 0.0;
    _lfIncentivePercent = AppConstants.lfIncentivePercent;
    _ppdPercent = AppConstants.ppdPercent;
    _bulkRebatePercent = AppConstants.bulkRebatePercent;
    _arrearsDpcAmount = AppConstants.arrearsDpcAmount;
    roundToTen = AppConstants.roundToTen;
    billOnKvah = AppConstants.billOnKvah;
    _facRatesByMonth = {};
  }
}

/// Persists [AppConfig] values per user in the Supabase `user_settings` table.
/// Loaded after login so bills always use the signed-in user's tariff.
class TariffStore {
  TariffStore._();

  static const _table = 'user_settings';

  static String? _currentUserId() {
    if (!SupabaseClientManager.isInitialized) return null;
    return SupabaseClientManager.client.auth.currentUser?.id;
  }

  /// Load tariff settings for the given user (or the signed-in user when
  /// [userId] is null). Falls back to [AppConstants] defaults when nothing
  /// is stored.
  static Future<void> load({String? userId}) async {
    final uid = userId ?? _currentUserId();
    if (uid == null) return;
    try {
      final data = await SupabaseClientManager.client
          .from(_table)
          .select('data')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      final raw = data?['data'];
      if (raw is Map) {
        _applyFromMap(
          raw.cast<String, Object?>(),
        );
      }
    } catch (e) {
      AppLogger.e('Failed to load tariff settings', e);
    }
  }

  static void _applyFromMap(Map<String, Object?> map) {
    void setDouble(String key, void Function(double) setter) {
      final v = map[key];
      if (v is num) setter(v.toDouble());
    }

    // Category + tariff year first — they pull in the official preset,
    // then individual rate keys below override anything customized.
    if (map['tariff_category'] is String || map['tariff_version'] is String) {
      AppConfig.applyTariffPreset(
        TariffCategory.fromId(map['tariff_category'] as String?),
        TariffVersion.fromId(map['tariff_version'] as String?),
      );
    }

    setDouble('tariff_per_unit', (v) => AppConfig.tariffPerUnit = v);
    setDouble('demand_charge_per_kva', (v) => AppConfig.demandChargePerKva = v);
    setDouble('fac_rate_per_unit', (v) => AppConfig.facRatePerUnit = v);
    setDouble('wheeling_charge_per_unit', (v) => AppConfig.wheelingChargePerUnit = v);

    // Duty: percentage of energy charges (official model). A flat per-unit
    // rate is only used as fallback for legacy data without a percent.
    if (map.containsKey('electricity_duty_percent')) {
      setDouble('electricity_duty_percent', (v) => AppConfig.dutyPercent = v);
    } else if (map.containsKey('electricity_duty_per_unit')) {
      setDouble('electricity_duty_per_unit', (v) => AppConfig.electricityDutyPerUnit = v);
    }
    if (map.containsKey('tax_per_unit')) {
      setDouble('tax_per_unit', (v) => AppConfig.taxPerUnit = v);
    } else if (map.containsKey('tax_percent')) {
      // Legacy: ignore old percentage, keep default per-unit
    }
    if (map.containsKey('tax_percent')) {
      setDouble('tax_percent', (v) => AppConfig.taxPercent = v);
    }
    setDouble('icr_rate_per_unit', (v) => AppConfig.icrRatePerUnit = v);
    setDouble('icr_last_year_units', (v) => AppConfig.icrLastYearUnits = v);
    setDouble('lf_incentive_percent', (v) => AppConfig.lfIncentivePercent = v);
    setDouble('ppd_percent', (v) => AppConfig.ppdPercent = v);
    setDouble('bulk_rebate_percent', (v) => AppConfig.bulkRebatePercent = v);
    setDouble('arrears_dpc_amount', (v) => AppConfig.arrearsDpcAmount = v);
    if (map['round_to_ten'] is bool) {
      AppConfig.roundToTen = map['round_to_ten'] as bool;
    }
    if (map['bill_on_kvah'] is bool) {
      AppConfig.billOnKvah = map['bill_on_kvah'] as bool;
    }
    final facMap = map['fac_rates_by_month'];
    if (facMap is Map) {
      AppConfig.facRatesByMonth = facMap.map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      );
    }
    setDouble('fixed_charge', (v) => AppConfig.fixedCharge = v);

    setDouble('subsidy_percent', (v) => AppConfig.subsidyPercent = v);
    setDouble('contract_demand_kva', (v) => AppConfig.contractDemandKva = v);

    final preceding = map['preceding_months_demand_kva'];
    if (preceding is List) {
      AppConfig.precedingDemandKva =
          preceding.map((e) => (e as num?)?.toDouble() ?? 0).toList();
    }

    setDouble('region_subsidy_amount', (v) => AppConfig.regionSubsidyAmount = v);
    setDouble('rebate_section_106', (v) => AppConfig.rebateSection106 = v);

    final todRaw = map['tod_multipliers'];
    if (todRaw is List && todRaw.length == 4) {
      AppConfig.todMultipliers = todRaw.map((e) => (e as num).toDouble()).toList();
    }
  }

  static Future<void> saveAll({
    required double tariffPerUnit,
    required double demandChargePerKva,
    required double facRatePerUnit,
    required double wheelingChargePerUnit,
    required double electricityDutyPerUnit,
    required double taxPerUnit,
    required double subsidyPercent,
    double contractDemandKva = AppConstants.defaultContractDemandKva,
    List<double>? precedingDemandKva,
    double regionSubsidyAmount = 0.0,
    double rebateSection106 = 0.0,
    List<double>? todMultipliers,
  }) async {
    final uid = _currentUserId();
    if (uid == null) {
      throw const RemoteStorageException('You must be signed in to save settings.');
    }
    try {
      final data = {
        'tariff_per_unit': tariffPerUnit,
        'demand_charge_per_kva': demandChargePerKva,
        'fac_rate_per_unit': facRatePerUnit,
        'wheeling_charge_per_unit': wheelingChargePerUnit,
        'electricity_duty_percent': AppConfig.dutyPercent,
        'tax_percent': AppConfig.taxPercent,
        'icr_rate_per_unit': AppConfig.icrRatePerUnit,
        'icr_last_year_units': AppConfig.icrLastYearUnits,
        'lf_incentive_percent': AppConfig.lfIncentivePercent,
        'ppd_percent': AppConfig.ppdPercent,
        'bulk_rebate_percent': AppConfig.bulkRebatePercent,
        'arrears_dpc_amount': AppConfig.arrearsDpcAmount,
        'round_to_ten': AppConfig.roundToTen,
        'bill_on_kvah': AppConfig.billOnKvah,
        'fac_rates_by_month': AppConfig.facRatesByMonth,
        'subsidy_percent': subsidyPercent,
        'contract_demand_kva': contractDemandKva,
        'tariff_category': AppConfig.tariffCategory.id,
        'tariff_version': AppConfig.tariffVersion.id,
        'fixed_charge': AppConfig.fixedCharge,
        'preceding_months_demand_kva':
            precedingDemandKva ?? AppConfig.precedingDemandKva,
        'region_subsidy_amount': regionSubsidyAmount,
        'rebate_section_106': rebateSection106,
        'tod_multipliers': todMultipliers ?? AppConfig.todMultipliers,
      };
      await SupabaseClientManager.client.from(_table).upsert({
        'user_id': uid,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      AppConfig.tariffPerUnit = tariffPerUnit;
      AppConfig.demandChargePerKva = demandChargePerKva;
      AppConfig.facRatePerUnit = facRatePerUnit;
      AppConfig.wheelingChargePerUnit = wheelingChargePerUnit;
      AppConfig.electricityDutyPerUnit = electricityDutyPerUnit;
      AppConfig.taxPerUnit = taxPerUnit;
      AppConfig.subsidyPercent = subsidyPercent;
      AppConfig.contractDemandKva = contractDemandKva;
      if (precedingDemandKva != null) {
        AppConfig.precedingDemandKva = precedingDemandKva;
      }
      AppConfig.regionSubsidyAmount = regionSubsidyAmount;
      AppConfig.rebateSection106 = rebateSection106;
      if (todMultipliers != null) AppConfig.todMultipliers = todMultipliers;
    } catch (e) {
      AppLogger.e('Failed to save tariff settings', e);
      rethrow;
    }
  }
  /// Saves (or clears, when [rate] is null/≤0) the per-month FAC rate for
  /// [monthKey] ("YYYY-MM") without touching the other tariff settings.
  static Future<void> saveFacRate(String monthKey, double? rate) async {
    final uid = _currentUserId();
    if (uid == null) {
      throw const RemoteStorageException('You must be signed in to save settings.');
    }
    try {
      final existing = await SupabaseClientManager.client
          .from(_table)
          .select('data')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      final data = Map<String, Object?>.from(
        (existing?['data'] as Map? ?? {}).cast<String, Object?>(),
      );
      final facMap = Map<String, double>.from(AppConfig.facRatesByMonth);
      if (rate == null || rate <= 0) {
        facMap.remove(monthKey);
      } else {
        facMap[monthKey] = rate;
      }
      data['fac_rates_by_month'] = facMap;
      AppConfig.facRatesByMonth = facMap;
      await SupabaseClientManager.client.from(_table).upsert({
        'user_id': uid,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      AppLogger.e('Failed to save monthly FAC rate', e);
      rethrow;
    }
  }
}

/// Stores actual bill amounts per month (Issue 7B) in the Supabase
/// `bill_reconcile` table so reports can reconcile them against the app's
/// estimated bill.
class BillReconcileStore {
  BillReconcileStore._();

  static const _table = 'bill_reconcile';

  static String? _currentUserId() {
    if (!SupabaseClientManager.isInitialized) return null;
    return SupabaseClientManager.client.auth.currentUser?.id;
  }

  static Future<Map<String, double>> load() async {
    final uid = _currentUserId();
    if (uid == null) return {};
    try {
      final data = await SupabaseClientManager.client
          .from(_table)
          .select('month_key,amount')
          .eq('user_id', uid);
      return {
        for (final row in (data as List<dynamic>))
          row['month_key'] as String: (row['amount'] as num).toDouble(),
      };
    } catch (e) {
      AppLogger.e('Failed to load actual bills', e);
      return {};
    }
  }

  static Future<void> saveActualBill(String monthKey, double amount) async {
    final uid = _currentUserId();
    if (uid == null) {
      throw const RemoteStorageException('You must be signed in to save bills.');
    }
    try {
      await SupabaseClientManager.client.from(_table).upsert({
        'user_id': uid,
        'month_key': monthKey,
        'amount': amount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      AppLogger.e('Failed to save actual bill', e);
      rethrow;
    }
  }

  static Future<void> clear() async {
    final uid = _currentUserId();
    if (uid == null) return;
    try {
      await SupabaseClientManager.client
          .from(_table)
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      AppLogger.e('Failed to clear actual bills', e);
    }
  }
}
