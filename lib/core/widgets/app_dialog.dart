import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;
  final bool destructive;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
    this.destructive = false,
  });

  static Future<bool?> show(BuildContext context, {
    required String title,
    required Widget content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    VoidCallback? onConfirm,
    IconData? icon,
    Color? iconColor,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: onConfirm ?? () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
        icon: icon,
        iconColor: iconColor,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 0),
      contentPadding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      actionsPadding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(title, textAlign: TextAlign.center),
        ],
      ),
      content: content,
      actions: [
        if (cancelLabel.isNotEmpty)
          TextButton(onPressed: onCancel, child: Text(cancelLabel)),
        AppButton(
          label: confirmLabel,
          onPressed: onConfirm,
          color: destructive ? const Color(0xFFEF4444) : null,
        ),
      ],
    );
  }
}
