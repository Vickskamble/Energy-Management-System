import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class _DeviceDetail {
  final String name;
  final double kW;
  final double kwh;
  final double pf;
  final double amps;
  final IconData icon;
  final bool warning;
  final String warningMsg;

  const _DeviceDetail({
    required this.name,
    required this.kW,
    required this.kwh,
    required this.pf,
    required this.amps,
    required this.icon,
    this.warning = false,
    this.warningMsg = '',
  });
}

final _devices = [
  _DeviceDetail(
    name: 'Air Compressor', kW: 22.4, kwh: 168, pf: 0.88, amps: 45,
    icon: Icons.air,
  ),
  _DeviceDetail(
    name: 'Main Motor Line', kW: 18.6, kwh: 140, pf: 0.85, amps: 38,
    icon: Icons.precision_manufacturing,
  ),
  _DeviceDetail(
    name: 'HVAC — Shop Floor', kW: 12.5, kwh: 94, pf: 0.78, amps: 26,
    icon: Icons.ac_unit, warning: true,
    warningMsg: 'Exceeds 10 kW threshold | Low PF 0.78',
  ),
  _DeviceDetail(
    name: 'Lighting Grid', kW: 7.9, kwh: 59, pf: 0.95, amps: 16,
    icon: Icons.light,
  ),
  _DeviceDetail(
    name: 'Auxiliary Load', kW: 4.6, kwh: 35, pf: 0.92, amps: 10,
    icon: Icons.memory,
  ),
];

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats
          Row(
            children: [
              _statBox('Total Load', '66.0 kW', Icons.bolt),
              const SizedBox(width: 12),
              _statBox('Devices', '5', Icons.memory),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox('Avg PF', '0.88', Icons.power),
              const SizedBox(width: 12),
              _statBox('Warnings', '1', Icons.warning, color: PowerTheme.danger),
            ],
          ),
          const SizedBox(height: 24),

          Text('All Devices', style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 12),

          ..._devices.map((d) => _deviceCard(d)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, {Color? color}) {
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
                    style: PowerTextStyles.mono(size: 15, color: PowerTheme.textPrimary)),
                Text(label,
                    style: PowerTextStyles.body(size: 11, color: PowerTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(_DeviceDetail d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PowerTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d.warning ? PowerTheme.danger.withAlpha(80) : PowerTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: d.warning ? PowerTheme.danger.withAlpha(20) : PowerTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(d.icon, size: 18,
                    color: d.warning ? PowerTheme.danger : PowerTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: PowerTextStyles.body(size: 14, weight: FontWeight.w600)),
                    if (d.warning)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: PowerTheme.danger.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(d.warningMsg,
                            style: PowerTextStyles.body(size: 10, color: PowerTheme.danger)),
                      ),
                  ],
                ),
              ),
              Text('${d.kW}',
                  style: PowerTextStyles.mono(size: 18, color: PowerTheme.textPrimary)),
              const SizedBox(width: 4),
              Text('kW', style: TextStyle(fontSize: 11, color: PowerTheme.textMuted)),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _metric('Today', '${d.kwh} kWh'),
              _metric('PF', d.pf.toStringAsFixed(2)),
              _metric('Current', '${d.amps} A'),
              _metric('Load', '${(d.kW / 22.4 * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: d.kW / 22.4,
              minHeight: 4,
              backgroundColor: PowerTheme.surface,
              valueColor: AlwaysStoppedAnimation(
                  d.warning ? PowerTheme.danger : PowerTheme.lime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: PowerTextStyles.mono(size: 12, color: PowerTheme.textPrimary)),
          Text(label,
              style: PowerTextStyles.body(size: 10, color: PowerTheme.textMuted)),
        ],
      ),
    );
  }
}
