import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import '../database/database_factory.dart';
import 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart'
    as save;

/// Full local-data backup/restore (Issue 12).
///
/// Exports every record of the three local sembast databases
/// (energy logs, meters, meta/settings) as a single JSON file, and can
/// restore that file later — including on a different device.
class BackupService {
  BackupService._();

  static const List<String> _dbFiles = [
    'ems_energy_logs.db',
    'ems_meters.db',
    'ems_meta.db',
  ];

  static Future<void> exportBackup() async {
    final payload = <String, List<Object?>>{};
    for (final name in _dbFiles) {
      final db = await getDatabaseFactory().openDatabase(name);
      final lines = await exportDatabaseLines(db);
      payload[name] = lines;
    }

    final json = jsonEncode({
      'ems_backup': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'dbs': payload,
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

    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (root['ems_backup'] != 1) {
      throw StateError('Not a valid EMS backup file');
    }
    final dbs = root['dbs'] as Map<String, dynamic>;

    var recordCount = 0;
    final restored = <String>[];
    for (final name in _dbFiles) {
      final lines = (dbs[name] as List<dynamic>? ?? []);
      final db = await getDatabaseFactory().openDatabase(name);

      // Drop every store currently present in the live database.
      final existing = await exportDatabaseLines(db);
      final storeNames = <String>{};
      for (final line in existing.skip(1)) {
        if (line is Map) {
          final storeName = line['store']?.toString();
          if (storeName != null) storeNames.add(storeName);
        }
      }
      for (final storeName in storeNames) {
        await stringMapStoreFactory.store(storeName).delete(db);
      }

      // Restore records, preserving int vs string key type.
      String? currentStore;
      for (final line in lines.skip(1)) {
        if (line is Map) {
          currentStore = line['store']?.toString();
        } else if (line is List && line.length >= 2) {
          final key = line[0];
          final value = line[1];
          if (currentStore == null || key == null || value == null) continue;
          final ref = key is int
              ? intMapStoreFactory.store(currentStore)
              : stringMapStoreFactory.store(currentStore);
          await ref.record(key).put(db, value as Map<String, Object?>);
          recordCount++;
        }
      }
      restored.add(name);
    }

    return (recordCount: recordCount, restoredDbs: restored);
  }
}
