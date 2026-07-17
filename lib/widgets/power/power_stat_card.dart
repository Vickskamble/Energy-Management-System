import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class PowerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? delta;
  final bool isLime;

  const PowerStatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.isLime = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta?.startsWith('+') ?? true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLime ? PowerTheme.lime : PowerTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLime ? PowerTheme.lime : PowerTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PowerTextStyles.body(
              size: 12,
              color: isLime ? PowerTheme.onLime.withAlpha(180) : PowerTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: PowerTextStyles.mono(
                  size: 28,
                  color: isLime ? PowerTheme.onLime : PowerTheme.textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: PowerTextStyles.body(
                    size: 13,
                    color: isLime ? PowerTheme.onLime.withAlpha(180) : PowerTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isUp ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isLime ? PowerTheme.onLime : PowerTheme.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: PowerTextStyles.body(
                    size: 11,
                    color: isLime ? PowerTheme.onLime : PowerTheme.danger,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
