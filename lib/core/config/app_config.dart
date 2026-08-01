import 'package:sembast/sembast.dart';
import '../database/database_factory.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Runtime-configurable tariff settings (persisted locally).
/// Falls back to [AppConstants] defaults when nothing is stored.
class AppConfig {
  AppConfig._();

  static double _tariffPerUnit = AppConstants.tariffPerUnit;
  static double _demandChargePerKva = AppConstants.demandChargePerKva;
  static double _facRatePerUnit = AppConstants.facRatePerUnit;
  static double _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
  static double _electricityDutyPercent = AppConstants.electricityDutyPercent;
  static double _taxPercent = AppConstants.taxPercent;
  static double _subsidyPercent = AppConstants.subsidyPercent;

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

  /// Electricity duty percentage on subtotal.
  static double get electricityDutyPercent => _electricityDutyPercent;

  static set electricityDutyPercent(double value) {
    if (value >= 0) _electricityDutyPercent = value;
  }

  /// Additional tax percentage.
  static double get taxPercent => _taxPercent;

  static set taxPercent(double value) {
    if (value >= 0) _taxPercent = value;
  }

  /// Subsidy percentage (0 when none).
  static double get subsidyPercent => _subsidyPercent;

  static set subsidyPercent(double value) {
    if (value >= 0) _subsidyPercent = value;
  }

  static void reset() {
    _tariffPerUnit = AppConstants.tariffPerUnit;
    _demandChargePerKva = AppConstants.demandChargePerKva;
    _facRatePerUnit = AppConstants.facRatePerUnit;
    _wheelingChargePerUnit = AppConstants.wheelingChargePerUnit;
    _electricityDutyPercent = AppConstants.electricityDutyPercent;
    _taxPercent = AppConstants.taxPercent;
    _subsidyPercent = AppConstants.subsidyPercent;
  }
}

/// Persists [AppConfig] values in a local sembast meta database.
class TariffStore {
  TariffStore._();

  static const _recordKey = 'tariff';

  static Future<void> load() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');

      final rec = await store.record(_recordKey).get(db);
      if (rec != null) {
        _applyFromMap(rec);
        return;
      }

      // Legacy single-value record ('tariff_per_unit') written by older builds.
      final legacy = await store.record('tariff_per_unit').get(db);
      final legacyValue = legacy?['value'];
      if (legacyValue is num && legacyValue > 0) {
        AppConfig.tariffPerUnit = legacyValue.toDouble();
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
    setDouble(
      'wheeling_charge_per_unit',
      (v) => AppConfig.wheelingChargePerUnit = v,
    );
    setDouble(
      'electricity_duty_percent',
      (v) => AppConfig.electricityDutyPercent = v,
    );
    setDouble('tax_percent', (v) => AppConfig.taxPercent = v);
    setDouble('subsidy_percent', (v) => AppConfig.subsidyPercent = v);
  }

  static Future<void> saveAll({
    required double tariffPerUnit,
    required double demandChargePerKva,
    required double facRatePerUnit,
    required double wheelingChargePerUnit,
    required double electricityDutyPercent,
    required double taxPercent,
    required double subsidyPercent,
  }) async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      await store.record(_recordKey).put(db, {
        'tariff_per_unit': tariffPerUnit,
        'demand_charge_per_kva': demandChargePerKva,
        'fac_rate_per_unit': facRatePerUnit,
        'wheeling_charge_per_unit': wheelingChargePerUnit,
        'electricity_duty_percent': electricityDutyPercent,
        'tax_percent': taxPercent,
        'subsidy_percent': subsidyPercent,
      });

      AppConfig.tariffPerUnit = tariffPerUnit;
      AppConfig.demandChargePerKva = demandChargePerKva;
      AppConfig.facRatePerUnit = facRatePerUnit;
      AppConfig.wheelingChargePerUnit = wheelingChargePerUnit;
      AppConfig.electricityDutyPercent = electricityDutyPercent;
      AppConfig.taxPercent = taxPercent;
      AppConfig.subsidyPercent = subsidyPercent;
    } catch (e) {
      AppLogger.e('Failed to save tariff settings', e);
      rethrow;
    }
  }
}

/// Stores actual bill amounts per month (Issue 7B) so reports can reconcile
/// them against the app's estimated bill.
class BillReconcileStore {
  BillReconcileStore._();

  static const _recordKey = 'bill_reconcile';

  static Future<Map<String, double>> load() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      final rec = await store.record(_recordKey).get(db);
      if (rec == null) return {};
      return rec.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
    } catch (e) {
      AppLogger.e('Failed to load actual bills', e);
      return {};
    }
  }

  static Future<void> saveActualBill(String monthKey, double amount) async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      final rec = await store.record(_recordKey).get(db);
      final map = Map<String, Object?>.from(rec ?? const {});
      map[monthKey] = amount;
      await store.record(_recordKey).put(db, map);
    } catch (e) {
      AppLogger.e('Failed to save actual bill', e);
      rethrow;
    }
  }

  static Future<void> clear() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      await store.record(_recordKey).delete(db);
    } catch (e) {
      AppLogger.e('Failed to clear actual bills', e);
    }
  }
}
