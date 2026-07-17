import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // OpenAI Configuration
  static String get openAiApiKey =>
      dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get openAiModel =>
      dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini';

  // Supabase Configuration
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // App settings
  static const String appName = 'EMS - Energy Management System';
  static const String appVersion = '1.0.0';
  static const int readingsToAnalyze = 60;
  static const int analysisRetentionDays = 90;
}
