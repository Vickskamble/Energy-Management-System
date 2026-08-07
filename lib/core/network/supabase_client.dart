import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'secure_supabase_storage.dart';

class SupabaseClientManager {
  static SupabaseClient? _instance;

  static Future<SupabaseClient> initialize() async {
    if (_instance != null) return _instance!;

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase credentials not found. Check SUPABASE_URL and SUPABASE_ANON_KEY in .env',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseStorage(),
      ),
    );

    _instance = Supabase.instance.client;
    return _instance!;
  }

  static SupabaseClient get client {
    if (_instance == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseClientManager.initialize() first',
      );
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;
}
