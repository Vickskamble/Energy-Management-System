import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase [LocalStorage] backed by platform-secure storage
/// (Android Keystore / iOS Keychain / Windows DPAPI / WebCrypto).
///
/// Replaces the default plaintext SharedPreferences / localStorage session
/// persistence (SECURITY.md gap G3).
class SecureSupabaseStorage extends LocalStorage {
  SecureSupabaseStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'sb-auth-token';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _sessionKey)) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}
