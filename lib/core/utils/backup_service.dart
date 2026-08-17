import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/remote/energy_log_remote_datasource.dart';
import '../../data/datasources/remote/meter_remote_datasource.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/models/meter_model.dart';
import '../network/supabase_client.dart';
import 'validation_rules.dart';
import 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart'
    as save;

/// Raised when a restore target is an encrypted backup and no passphrase
/// was supplied — the caller should prompt the user and retry.
class BackupEncryptionRequired implements Exception {
  @override
  String toString() => 'This backup is encrypted — a passphrase is required.';
}

/// Full cloud-data backup/restore with optional passphrase encryption.
///
/// Exports the signed-in user's Supabase data (energy logs, meters, tariff
/// settings, actual bills) as a single JSON file, and can restore that file
/// later — including on a different device (rows are re-claimed for the
/// current user).
///
/// Encryption (SECURITY.md gap "encrypted backups"): the JSON payload is
/// sealed with AES-256-GCM using a key derived from the passphrase via
/// PBKDF2-HMAC-SHA256 (100,000 iterations, random 16-byte salt). The stored
/// file is a JSON container holding the base64-encoded salt, nonce, MAC and
/// ciphertext — without the passphrase the payload is unrecoverable.
class BackupService {
  BackupService._();

  static const int _version = 2;

  /// PBKDF2 work factor — OWASP-recommended floor for AES-256-GCM keys.
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  /// Max restore file size (bytes) — guards against crafted files that
  /// exhaust memory or JSON nesting (SECURITY.md gap G8).
  static const int maxRestoreSizeBytes = 20 * 1024 * 1024; // 20 MB

  /// Fetch ALL logs via pagination (default limit caps at 1000 rows, so
  /// plain fetchLogs would silently truncate large histories).
  static Future<List<EnergyLogModel>> _fetchAllLogs() async {
    const pageSize = 1000;
    final all = <EnergyLogModel>[];
    var offset = 0;
    while (true) {
      final batch = await EnergyLogRemoteDatasource().fetchLogs(
        limit: pageSize,
        offset: offset,
      );
      all.addAll(batch);
      if (batch.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  static Future<void> exportBackup({String? passphrase}) async {
    final client = SupabaseClientManager.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('You must be signed in to export data.');

    final logs = await _fetchAllLogs();

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

    final payload = jsonEncode({
      'ems_backup': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'energy_logs': logs.map((l) => l.toJson()).toList(),
      'user_meters': meters.map((m) => m.toJson()).toList(),
      'settings': settingsRow?['data'],
      'bill_reconcile': (billRows as List<dynamic>)
          .map((r) => {'month_key': r['month_key'], 'amount': r['amount']})
          .toList(),
    });

    // Plaintext export when no passphrase is supplied — easier for users who
    // just want a quick copy. Keep the file secure; it is unencrypted.
    if (passphrase == null || passphrase.isEmpty) {
      final stamp = DateTime.now().toIso8601String().split('T').first;
      await save.saveBytes(
        Uint8List.fromList(utf8.encode(payload)),
        'ems_backup_$stamp.json',
        'application/json',
      );
      return;
    }

    final encrypted = await _encrypt(utf8.encode(payload), passphrase);
    final container = jsonEncode({
      'ems_enc_backup': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'salt': base64Encode(encrypted.salt),
      'nonce': base64Encode(encrypted.nonce),
      'mac': base64Encode(encrypted.mac),
      'ciphertext': base64Encode(encrypted.cipherText),
    });

    final stamp = DateTime.now().toIso8601String().split('T').first;
    await save.saveBytes(
      Uint8List.fromList(utf8.encode(container)),
      'ems_backup_enc_$stamp.json',
      'application/json',
    );
  }

  static Future<({int recordCount, List<String> restoredDbs})>
  restoreBackup({String? passphrase}) async {
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

    // Encrypted backups (v2, AES-256-GCM) — passphrase required.
    if (root['ems_enc_backup'] == _version) {
      if (passphrase == null || passphrase.isEmpty) {
        throw BackupEncryptionRequired();
      }
      final plain = await _decrypt(root, passphrase);
      final data =
          jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      if (data['ems_backup'] != _version) {
        throw StateError('Not a valid cloud backup file (expected version $_version).');
      }
      return _restorePayload(data, client, uid);
    }

    // Legacy plaintext backups remain supported for migration.
    if (root['ems_backup'] != _version) {
      throw StateError(
        'Not a valid cloud backup file (expected version $_version).',
      );
    }
    return _restorePayload(root, client, uid);
  }

  static Future<({int recordCount, List<String> restoredDbs})>
  _restorePayload(
    Map<String, dynamic> data,
    SupabaseClient client,
    String uid,
  ) async {
    var recordCount = 0;
    final restored = <String>[];

    // 1. Energy logs — re-claim every row for the current user.
    final logs = (data['energy_logs'] as List<dynamic>? ?? []);
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
    final meters = (data['user_meters'] as List<dynamic>? ?? []);
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
    final settings = data['settings'];
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
    final bills = (data['bill_reconcile'] as List<dynamic>? ?? []);
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

  // ---- Encryption helpers ----

  static List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Future<
    ({Uint8List salt, Uint8List nonce, Uint8List mac, Uint8List cipherText})
  >
  _encrypt(List<int> plain, String passphrase) async {
    final error = ValidationRules.validatePassword(passphrase);
    if (error != null) {
      throw StateError(
        'Passphrase too weak — min ${ValidationRules.minPasswordLength} '
        'characters with at least one letter and one number.',
      );
    }
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(passphrase, salt);
    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    return (
      salt: Uint8List.fromList(salt),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
      cipherText: Uint8List.fromList(box.cipherText),
    );
  }

  static Future<Uint8List> _decrypt(
    Map<String, dynamic> container,
    String passphrase,
  ) async {
    try {
      final salt = base64Decode(container['salt'] as String);
      final nonce = base64Decode(container['nonce'] as String);
      final mac = base64Decode(container['mac'] as String);
      final cipherText = base64Decode(container['ciphertext'] as String);
      final key = await _deriveKey(passphrase, salt);
      final box = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
      return Uint8List.fromList(clear);
    } catch (e) {
      throw StateError(
        'Could not decrypt backup — wrong passphrase or corrupted file.',
      );
    }
  }
}
