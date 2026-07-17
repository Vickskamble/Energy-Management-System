import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class _AlertItem {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final String severity;

  const _AlertItem({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.severity,
  });
}

final _alerts = [
  _AlertItem(
    title: 'Overload Warning',
    message: 'HVAC — Shop Floor drawing 12.5 kW, exceeds 10 kW threshold',
    time: '2 min ago',
    icon: Icons.warning_amber_rounded,
    color: PowerTheme.danger,
    severity: 'Critical',
  ),
  _AlertItem(
    title: 'Low Power Factor',
    message: 'PF 0.78 on Main Motor Line — capacitor bank inspection needed',
    time: '15 min ago',
    icon: Icons.error_outline,
    color: PowerTheme.lime,
    severity: 'Warning',
  ),
  _AlertItem(
    title: 'Voltage Sag',
    message: '385V on Air Compressor at 08:14 AM — check supply',
    time: '4 hours ago',
    icon: Icons.cancel_outlined,
    color: PowerTheme.danger,
    severity: 'Critical',
  ),
  _AlertItem(
    title: 'Peak Demand Alert',
    message: "Today's peak 68.2 kW at 10:00 AM — 85% of contract demand",
    time: '3 hours ago',
    icon: Icons.info_outline,
    color: PowerTheme.textMuted,
    severity: 'Info',
  ),
  _AlertItem(
    title: 'High THD Warning',
    message: 'THD 11.5% on Main Motor Line — harmonic filter may be needed',
    time: '6 hours ago',
    icon: Icons.waves,
    color: PowerTheme.lime,
    severity: 'Warning',
  ),
  _AlertItem(
    title: 'Energy Saving Opportunity',
    message: 'Shift Air Compressor to off-peak hours — save ₹2,500/month',
    time: '1 day ago',
    icon: Icons.savings,
    color: PowerTheme.lime,
    severity: 'Info',
  ),
];

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final critical = _alerts.where((a) => a.severity == 'Critical').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _statCard('Total Alerts', '${_alerts.length}', Icons.notifications),
              const SizedBox(width: 12),
              _statCard('Critical', '$critical', Icons.warning,
                  color: PowerTheme.danger),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('Warnings',
                  '${_alerts.where((a) => a.severity == 'Warning').length}',
                  Icons.error_outline, color: PowerTheme.lime),
              const SizedBox(width: 12),
              _statCard('Resolved', '3', Icons.check_circle,
                  color: PowerTheme.textMuted),
            ],
          ),
          const SizedBox(height: 24),

          Text('All Alerts', style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 12),

          ..._alerts.map((a) => _alertCard(a)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PowerTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PowerTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? PowerTheme.textMuted),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: PowerTextStyles.mono(size: 18, color: PowerTheme.textPrimary)),
                Text(label,
                    style: PowerTextStyles.body(size: 11, color: PowerTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(_AlertItem a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PowerTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: a.color == PowerTheme.danger
              ? a.color.withAlpha(60)
              : PowerTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: a.color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(a.icon, size: 18, color: a.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(a.title,
                        style: PowerTextStyles.body(size: 14, weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: a.color.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(a.severity,
                          style: PowerTextStyles.body(size: 10, color: a.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.message, style: PowerTextStyles.body(size: 13, color: PowerTheme.textMuted)),
                const SizedBox(height: 4),
                Text(a.time, style: PowerTextStyles.body(size: 11, color: PowerTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
