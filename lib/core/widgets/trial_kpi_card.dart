import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Stat card cloned 1:1 from the v1.2.5 trial UI (powerems_v125_trial.html):
/// uppercase dim title (11.5px, letter-spaced), optional NEW badge, 22px/800
/// tabular value, 11px dim sub and a 7px fill bar. All colours resolve from
/// the active theme so every text stays readable in light and dark mode.
class TrialKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final Color color;
  final double pct;
  final bool badgeNew;

  const TrialKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
    required this.pct,
    this.badgeNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dim = dark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final line = dark ? AppColors.borderDark : AppColors.borderLight;
    final track = dark ? AppColors.surface2Dark : AppColors.surface2Light;
    final badgeColor =
        dark ? AppColors.primaryLight : AppColors.primaryDark;
    final badgeBg =
        AppColors.primary.withValues(alpha: 0.15);
    // Status colors are vivid (good on dark) but fail AA on white — switch to
    // the darker text variants on light surfaces for the headline value.
    final valueColor = AppColors.statusText(color, dark);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: dim,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    height: 1.2,
                  ),
                ),
              ),
              if (badgeNew) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 11,
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: value,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              color: dim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: track),
                  FractionallySizedBox(
                    widthFactor: (pct / 100).clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}