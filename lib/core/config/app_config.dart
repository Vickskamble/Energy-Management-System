import 'package:sembast/sembast.dart';
import '../database/database_factory.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Runtime-configurable settings (persisted locally).
/// Falls back to [AppConstants] defaults when nothing is stored.
class AppConfig {
  AppConfig._();

  static double _tariffPerUnit = AppConstants.tariffPerUnit;

  /// Effective energy tariff per unit (₹/kWh) — editable via Settings.
  static double get tariffPerUnit => _tariffPerUnit;

  static set tariffPerUnit(double value) {
    if (value > 0) _tariffPerUnit = value;
  }

  static void reset() {
    _tariffPerUnit = AppConstants.tariffPerUnit;
  }
}

/// Persists [AppConfig] values in a local sembast meta database.
class TariffStore {
  TariffStore._();

  static Future<void> load() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      final rec = await store.record('tariff_per_unit').get(db);
      final value = rec?['value'];
      if (value is num && value > 0) {
        AppConfig.tariffPerUnit = value.toDouble();
      }
    } catch (e) {
      AppLogger.e('Failed to load tariff settings', e);
    }
  }

  static Future<void> saveTariff(double tariffPerUnit) async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      await store.record('tariff_per_unit').put(db, {'value': tariffPerUnit});
      AppConfig.tariffPerUnit = tariffPerUnit;
    } catch (e) {
      AppLogger.e('Failed to save tariff settings', e);
    }
  }
}
