import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/database_factory.dart';
import '../utils/app_logger.dart';
import 'supabase_client.dart';


/// Result of a single-device session check.
enum SessionStatus {
  /// This device is (or may become) the active session.
  ok,

  /// Another device holds a fresh session for the same account.
  conflict,
}

/// Enforces one-device-per-account login.
///
/// Each device gets a persistent [device_token] (stored in the local sembast
/// meta db). A `user_sessions` row on Supabase records which device currently
/// owns the session plus its `last_seen_at` heartbeat timestamp.
///
/// Rules:
///  - Login is allowed when no fresh session exists, the row belongs to this
///    device, or the row is stale (last_seen older than [_staleAfter]).
///  - Login is blocked when another device holds a fresh session.
///  - While logged in, a heartbeat refreshes `last_seen_at`; if another device
///    ever takes over the row, the next heartbeat detects the conflict and the
///    app force-signs-out this device.
///
/// [isExempt] accounts (the public demo account) are NOT restricted — anyone
/// can log in anytime, because multiple clients try the demo simultaneously.
///
/// Requires the `supabase_single_device_migration.sql` migration to be applied.
class SessionGuard {
  SessionGuard._();

  static final SessionGuard instance = SessionGuard._();

  static const String _table = 'user_sessions';
  static const Duration _staleAfter = Duration(minutes: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  /// Accounts exempt from single-device enforcement — the public demo
  /// account must stay usable for every client at the same time.
  static const List<String> _exemptEmails = ['demo@powerems.com'];

  /// Whether [email] is exempt from single-device session enforcement.
  static bool isExempt(String email) =>
      _exemptEmails.contains(email.toLowerCase().trim());

  Timer? _heartbeat;
  String? _activeUserId;
  String? _deviceToken;

  SupabaseClient get _client => SupabaseClientManager.client;

  /// Stable per-browser/per-device token, persisted in local sembast meta db.
  Future<String> getDeviceToken() async {
    if (_deviceToken != null) return _deviceToken!;
    try {
      final db = await openMetaDatabase();
      final store = stringMapStoreFactory.store('meta');
      final rec = await store.record('device_token').get(db);
      var token = rec?['value'];
      if (token is String && token.isNotEmpty) {
        _deviceToken = token;
        return token;
      }
      // Legacy: the token may live in the old CWD-relative ems_meta.db from
      // previous desktop builds — migrate it so no false conflict occurs.
      final legacy = await _readLegacyToken();
      if (legacy is String && legacy.isNotEmpty) {
        await store.record('device_token').put(db, {'value': legacy});
        _deviceToken = legacy;
        return legacy;
      }
      token = const Uuid().v4();
      await store.record('device_token').put(db, {'value': token});
      _deviceToken = token;
      return token;
    } catch (e) {
      AppLogger.e('Failed to read device token (fallback in-memory)', e);
      _deviceToken = const Uuid().v4();
      return _deviceToken!;
    }
  }

  Future<String?> _readLegacyToken() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('meta');
      final rec = await store.record('device_token').get(db);
      final token = rec?['value'];
      return token is String && token.isNotEmpty ? token : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether this device may log in for [userId].
  ///
  /// Fail-open on errors (table missing / network down / timeout) so the app
  /// keeps working until the migration has been applied.
  Future<SessionStatus> check(String userId) async {
    final token = await getDeviceToken();
    try {
      final rows = await _client
          .from(_table)
          .select('device_token,last_seen_at')
          .eq('user_id', userId)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (rows.isEmpty) return SessionStatus.ok;
      final row = rows.first;
      final otherToken = row['device_token'];
      if (otherToken is String && otherToken == token) {
        return SessionStatus.ok;
      }
      final lastSeen = DateTime.tryParse(row['last_seen_at']?.toString() ?? '');
      final stale = lastSeen == null ||
          DateTime.now().toUtc().difference(lastSeen.toUtc()) > _staleAfter;
      return stale ? SessionStatus.ok : SessionStatus.conflict;
    } catch (e) {
      AppLogger.e('SessionGuard.check failed (fail-open)', e);
      return SessionStatus.ok;
    }
  }

  /// Claim (or renew) the session row for this device.
  Future<void> takeOver(String userId) async {
    final token = await getDeviceToken();
    try {
      await _client.from(_table).upsert({
        'user_id': userId,
        'device_token': token,
        'device_name': _deviceName(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      AppLogger.e('SessionGuard.takeOver failed', e);
    }
  }

  /// Take over the session row even when another device currently holds it
  /// (last login wins). Only used when this device proves it is a *returning*
  /// device — a session for the same user was restored from this device's own
  /// storage — so a leftover row from a killed app session can never lock the
  /// user out of their own device.
  Future<void> forceTakeOver(String userId) async {
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
      await takeOver(userId);
    } catch (e) {
      AppLogger.e('SessionGuard.forceTakeOver failed', e);
    }
  }

  /// Refresh `last_seen_at`. Returns [SessionStatus.conflict] when the row is
  /// no longer owned by this device (someone else took over).
  Future<SessionStatus> heartbeat(String userId) async {
    final token = await getDeviceToken();
    try {
      final data = await _client
          .from(_table)
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .eq('device_token', token)
          .select('device_token');
      if (data.isNotEmpty) return SessionStatus.ok;
      return check(userId);
    } catch (e) {
      AppLogger.e('SessionGuard.heartbeat failed (fail-open)', e);
      return SessionStatus.ok;
    }
  }

  /// Remove the session row, but only if this device still owns it.
  Future<void> release(String userId) async {
    final token = await getDeviceToken();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .eq('device_token', token);
    } catch (e) {
      AppLogger.e('SessionGuard.release failed', e);
    }
  }

  /// Start the periodic heartbeat. Restarts if already running.
  void startHeartbeat({
    required String userId,
    required Future<void> Function() onConflict,
  }) {
    stopHeartbeat();
    _activeUserId = userId;
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) async {
      final status = await heartbeat(userId);
      if (status == SessionStatus.conflict) {
        await onConflict();
      }
    });
  }

  /// Stop the heartbeat; optionally release the session row.
  Future<void> stopHeartbeat({bool releaseSession = false}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final uid = _activeUserId;
    _activeUserId = null;
    if (releaseSession && uid != null) {
      await release(uid);
    }
  }

  String _deviceName() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Device';
    }
  }

  /// Small helper for tests / diagnostics.
  static String debugId() => const Uuid().v4();
}
