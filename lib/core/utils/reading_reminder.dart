import 'package:sembast/sembast.dart';
import '../database/database_factory.dart';
import '../utils/app_logger.dart';
import '../utils/notification_service.dart';

/// Month-end reading reminder (Issue 7F).
///
/// Fires at most once per month: during the last 3 days of the month, when no
/// reading has been recorded this month. The "already shown" flag lives in the
/// local sembast meta database so it survives app restarts.
class ReadingReminderService {
  ReadingReminderService._();

  static Future<void> maybeRemind({required int readingCountThisMonth}) async {
    try {
      final now = DateTime.now();
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      if (now.day < lastDay - 2) return;
      if (readingCountThisMonth > 0) return;

      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('settings');
      final flagKey = 'reading_reminder_${now.year}_${now.month}';
      final sent = await store.record(flagKey).get(db);
      if (sent != null) return;

      await store.record(flagKey).put(db, <String, Object?>{'sent': true});
      await NotificationService.instance.showReadingReminder();
    } catch (e) {
      AppLogger.e('Reading reminder check failed', e);
    }
  }
}
