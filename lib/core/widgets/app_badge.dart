import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final double fontSize;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.fontSize = 11,
    this.icon,
  });

  factory AppBadge.success(String label, {IconData? icon}) => AppBadge(label: label, color: AppColors.success, textColor: AppColors.textOnPrimary, icon: icon);
  factory AppBadge.warning(String label, {IconData? icon}) => AppBadge(label: label, color: AppColors.warning, textColor: AppColors.textOnPrimary, icon: icon);
  factory AppBadge.danger(String label, {IconData? icon}) => AppBadge(label: label, color: AppColors.danger, textColor: AppColors.textOnPrimary, icon: icon);
  factory AppBadge.info(String label, {IconData? icon}) => AppBadge(label: label, color: AppColors.info, textColor: AppColors.textOnPrimary, icon: icon);
  factory AppBadge.neutral(String label, {IconData? icon}) => AppBadge(label: label, color: AppColors.textSecondary, textColor: AppColors.textOnPrimary, icon: icon);

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 1, color: bgColor), const SizedBox(width: 3)],
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: bgColor)),
        ],
      ),
    );
  }
}
