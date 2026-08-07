import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../data/datasources/remote/energy_log_remote_datasource.dart';
import '../../data/datasources/remote/meter_remote_datasource.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/models/meter_model.dart';
import '../network/supabase_client.dart';
import 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart'
    as save;

/// Full cloud-data backup/restore.
///
/// Exports the signed-in user's Supabase data (energy logs, meters, tariff
/// settings, actual bills) as a single JSON file, and can restore that file
/// later — including on a different device (rows are re-claimed for the
/// current user).
class BackupService {
  BackupService._();

  static const int _version = 2;

  /// Max restore file size (bytes) — guards against crafted files that
  /// exhaust memory or JSON nesting (SECURITY.md gap G8).
  static const int maxRestoreSizeBytes = 20 * 1024 * 1024; // 20 MB

  static Future<void> exportBackup() async {
    final client = SupabaseClientManager.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('You must be signed in to export data.');

    final logs = await EnergyLogRemoteDatasource().fetchLogs(limit: 1000);
    final meters = await MeterRemoteDatasource().getAllMeters();

    final settingsRow = await client
        .from('user_settings')
        .select('data')
        .eq('user_id', uid)
        .maybeSingle();

    final billRows = await client
        .from('bill_reconcile')
        .select('month_key,amount')
        .eq('user_id', uid);

    final json = jsonEncode({
      'ems_backup': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'energy_logs': logs.map((l) => l.toJson()).toList(),
      'user_meters': meters.map((m) => m.toJson()).toList(),
      'settings': settingsRow?['data'],
      'bill_reconcile': (billRows as List<dynamic>)
          .map((r) => {'month_key': r['month_key'], 'amount': r['amount']})
          .toList(),
    });

    final stamp = DateTime.now().toIso8601String().split('T').first;
    await save.saveBytes(
      Uint8List.fromList(utf8.encode(json)),
      'ems_backup_$stamp.json',
      'application/json',
    );
  }

  static Future<({int recordCount, List<String> restoredDbs})>
  restoreBackup() async {
    final client = SupabaseClientManager.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('You must be signed in to restore data.');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw StateError('No file selected');
    }
    final bytes = result.files.first.bytes;
    if (bytes == null) throw StateError('Could not read backup file');
    if (bytes.lengthInBytes > BackupService.maxRestoreSizeBytes) {
      throw StateError(
        'Backup file is too large (max '
        '${BackupService.maxRestoreSizeBytes ~/ (1024 * 1024)} MB allowed).',
      );
    }

    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (root['ems_backup'] != _version) {
      throw StateError(
        'Not a valid cloud backup file (expected version $_version).',
      );
    }

    var recordCount = 0;
    final restored = <String>[];

    // 1. Energy logs — re-claim every row for the current user.
    final logs = (root['energy_logs'] as List<dynamic>? ?? []);
    if (logs.isNotEmpty) {
      final models = logs
          .map(
            (j) => EnergyLogModel.fromJson({
              ...(j as Map<String, dynamic>),
              'user_id': uid,
            }),
          )
          .toList();
      await EnergyLogRemoteDatasource().pushLogs(models);
      recordCount += models.length;
      restored.add('energy_logs');
    }

    // 2. Meters — user_id column defaults to the current user on insert.
    final meters = (root['user_meters'] as List<dynamic>? ?? []);
    if (meters.isNotEmpty) {
      final remote = MeterRemoteDatasource();
      for (final j in meters) {
        await remote.upsertMeter(
          MeterModel.fromJson(j as Map<String, dynamic>),
        );
      }
      recordCount += meters.length;
      restored.add('user_meters');
    }

    // 3. Tariff settings.
    final settings = root['settings'];
    if (settings is Map && settings.isNotEmpty) {
      await client.from('user_settings').upsert({
        'user_id': uid,
        'data': settings,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      recordCount += 1;
      restored.add('settings');
    }

    // 4. Actual bills.
    final bills = (root['bill_reconcile'] as List<dynamic>? ?? []);
    if (bills.isNotEmpty) {
      final payload = bills.map((r) {
        final row = r as Map<String, dynamic>;
        return {
          'user_id': uid,
          'month_key': row['month_key'],
          'amount': row['amount'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();
      await client.from('bill_reconcile').upsert(payload);
      recordCount += payload.length;
      restored.add('bill_reconcile');
    }

    return (recordCount: recordCount, restoredDbs: restored);
  }
}
