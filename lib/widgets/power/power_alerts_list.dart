import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class _Alert {
  final IconData icon;
  final Color color;
  final String message;
  final String time;
  const _Alert(this.icon, this.color, this.message, this.time);
}

final _alerts = [
  _Alert(Icons.warning_amber_rounded, PowerTheme.danger,
      'HVAC — Shop Floor is drawing 12.5 kW, above the 10 kW threshold',
      '2 min ago'),
  _Alert(Icons.error_outline, PowerTheme.lime,
      'Power factor dropped to 0.78 on Main Motor Line — capacitor bank may need service',
      '15 min ago'),
  _Alert(Icons.info_outline, PowerTheme.textMuted,
      'Today\'s peak demand: 68.2 kW at 10:00 AM', '3 hours ago'),
  _Alert(Icons.cancel_outlined, PowerTheme.danger,
      'Voltage sag detected on Air Compressor — 385V at 08:14 AM',
      '4 hours ago'),
];

class PowerAlertsList extends StatelessWidget {
  const PowerAlertsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PowerTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PowerTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Alerts', style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 12),
          ..._alerts.map(_buildAlert),
        ],
      ),
    );
  }

  Widget _buildAlert(_Alert a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PowerTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.icon, size: 16, color: a.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.message,
                  style: PowerTextStyles.body(size: 13, color: PowerTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  a.time,
                  style: PowerTextStyles.body(size: 11, color: PowerTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
