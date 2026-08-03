import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../network/supabase_client.dart';
import '../utils/app_logger.dart';

/// Runtime-configurable tariff settings (persisted locally).
/// Falls back to [AppConstants] defaults when nothing is stored.
class AppConfig {
  AppConfig._();

  static double _tariffPerUnit = AppConstants.tariffPerUnit;
  static double _demandChargePerKva = AppConstants.demandChargePerKva;
  static double _facRatePerUnit = AppConstants.facRatePerUnit;
  static double _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
  static double _electricityDutyPerUnit = AppConstants.electricityDutyPerUnit;
  static double _taxPerUnit = AppConstants.taxPerUnit;
  static double _subsidyPercent = AppConstants.subsidyPercent;
  static double _regionSubsidyAmount = 0.0;
  static double _rebateSection106 = 0.0;

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

  static void reset() {
    _tariffPerUnit = AppConstants.tariffPerUnit;
    _demandChargePerKva = AppConstants.demandChargePerKva;
    _facRatePerUnit = AppConstants.facRatePerUnit;
    _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
    _electricityDutyPerUnit = AppConstants.electricityDutyPerUnit;
    _taxPerUnit = AppConstants.taxPerUnit;
    _subsidyPercent = AppConstants.subsidyPercent;
    _regionSubsidyAmount = 0.0;
    _rebateSection106 = 0.0;
    _todMultipliers = [1.0, 1.0, 1.0, 1.0];
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
          .maybeSingle();
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

    setDouble('tariff_per_unit', (v) => AppConfig.tariffPerUnit = v);
    setDouble('demand_charge_per_kva', (v) => AppConfig.demandChargePerKva = v);
    setDouble('fac_rate_per_unit', (v) => AppConfig.facRatePerUnit = v);
    setDouble('wheeling_charge_per_unit', (v) => AppConfig.wheelingChargePerUnit = v);

    // Support legacy percentage keys → convert to per-unit fallback
    if (map.containsKey('electricity_duty_per_unit')) {
      setDouble('electricity_duty_per_unit', (v) => AppConfig.electricityDutyPerUnit = v);
    } else if (map.containsKey('electricity_duty_percent')) {
      // Legacy: ignore old percentage, keep default per-unit
    }
    if (map.containsKey('tax_per_unit')) {
      setDouble('tax_per_unit', (v) => AppConfig.taxPerUnit = v);
    } else if (map.containsKey('tax_percent')) {
      // Legacy: ignore old percentage, keep default per-unit
    }

    setDouble('subsidy_percent', (v) => AppConfig.subsidyPercent = v);
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
        'electricity_duty_per_unit': electricityDutyPerUnit,
        'tax_per_unit': taxPerUnit,
        'subsidy_percent': subsidyPercent,
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
      AppConfig.regionSubsidyAmount = regionSubsidyAmount;
      AppConfig.rebateSection106 = rebateSection106;
      if (todMultipliers != null) AppConfig.todMultipliers = todMultipliers;
    } catch (e) {
      AppLogger.e('Failed to save tariff settings', e);
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
