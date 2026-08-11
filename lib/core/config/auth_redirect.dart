import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the URL Supabase redirects to after an email confirmation /
/// password reset link is clicked.
///
/// Priority:
///  1. `APP_REDIRECT_URL` from `.env` — explicit override (e.g. production
///     site URL). Must be added to Supabase → Auth → URL Configuration →
///     Redirect URLs.
///  2. Web — the app's own origin/path (`Uri.base`), so dev (`flutter run
///     -d chrome`) and the GitHub Pages deployment both redirect right back
///     to the running app, which picks up the auth token automatically.
///  3. Mobile — custom deep link scheme (see AndroidManifest.xml / Info.plist).
///  4. Fallback — `http://localhost:3000` (Supabase default). On desktop the
///     email still gets confirmed server-side even if this page is not found;
///     the user can then sign in normally.
class AppAuthRedirect {
  AppAuthRedirect._();

  static const String mobileScheme = 'com.powerms.ems';

  static String resolve() {
    final override = dotenv.env['APP_REDIRECT_URL']?.trim() ?? '';
    if (override.isNotEmpty) return override;

    if (kIsWeb) {
      final base = Uri.base;
      return base.origin + base.path.replaceAll(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      return '$mobileScheme://login';
    }

    return 'http://localhost:3000';
  }
}
