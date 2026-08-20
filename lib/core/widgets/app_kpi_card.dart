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

class _AppKpiCardState extends State<AppKpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
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
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: widget.color.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.color.withValues(alpha: 0.45), widget.color],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color.withValues(alpha: 0.12),
                            widget.color.withValues(alpha: 0.28),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Icon(widget.icon, size: 20, color: widget.color),
                    ),
                    const Spacer(),
                    if (widget.trendValue != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (widget.trendUp
                                      ? AppColors.success
                                      : AppColors.danger)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.trendUp
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 12,
                              color: widget.trendUp
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.trendValue?.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.trendUp
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.dim(context),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: widget.description!,
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.dim(context),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _displayValue.toStringAsFixed(widget.decimals),
                      style: AppTypography.mono(
                        size: 24,
                        weight: FontWeight.w700,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.suffix,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                if (widget.trendLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.trendLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dim(context),
                    ),
                  ),
                ],
                if (widget.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dim(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
