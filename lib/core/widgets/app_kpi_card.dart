import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppKpiCard extends StatefulWidget {
  final String title;
  final double value;
  final String suffix;
  final IconData icon;
  final Color color;
  final double? trendValue;
  final bool trendUp;
  final String? trendLabel;
  final int decimals;
  final String? description;

  const AppKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
    this.trendValue,
    this.trendUp = true,
    this.trendLabel,
    this.decimals = 1,
    this.description,
  });

  @override
  State<AppKpiCard> createState() => _AppKpiCardState();
}

class _AppKpiCardState extends State<AppKpiCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      setState(() => _displayValue = widget.value * _anim.value);
    });
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AppKpiCard old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const Spacer(),
              if (widget.trendValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (widget.trendUp ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.trendUp ? Icons.trending_up : Icons.trending_down, size: 12,
                          color: widget.trendUp ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 2),
                      Text('${widget.trendValue?.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: widget.trendUp ? AppColors.success : AppColors.danger)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.title, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _displayValue.toStringAsFixed(widget.decimals),
                style: AppTypography.mono(size: 28, color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              Text(widget.suffix, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          if (widget.trendLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.trendLabel!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
          if (widget.description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.description!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
