import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// "By signing up or logging in, you consent to PowerEMS
/// Terms of Service and Privacy Policy." — links open the bundled docs.
class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        children: [
          const TextSpan(
            text: 'By signing up or logging in, you consent to PowerEMS ',
          ),
          _linkSpan(context, 'Terms of Service', 'docs/terms-of-service.md'),
          const TextSpan(text: ' and '),
          _linkSpan(context, 'Privacy Policy', 'docs/privacy-policy.md'),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  InlineSpan _linkSpan(BuildContext context, String label, String asset) {
    return WidgetSpan(
      child: GestureDetector(
        onTap: () => showLegalDocDialog(
          context,
          asset: asset,
          title: label,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Shows one of the bundled legal docs in a scrollable dialog.
Future<void> showLegalDocDialog(
  BuildContext context, {
  required String asset,
  required String title,
}) async {
  final content = await rootBundle.loadString(asset);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: SingleChildScrollView(
          child: SelectableText(
            _plainText(content),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Strips markdown headings/bold so the raw .md renders as plain text.
String _plainText(String markdown) {
  return markdown
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('*', '');
}