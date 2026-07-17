import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class _Device {
  final String name;
  final double kW;
  final IconData icon;
  final bool warning;
  const _Device(this.name, this.kW, this.icon, this.warning);
}

final _devices = [
  _Device('Air Compressor', 22.4, Icons.air, false),
  _Device('Main Motor Line', 18.6, Icons.precision_manufacturing, false),
  _Device('HVAC — Shop Floor', 12.5, Icons.ac_unit, true),
  _Device('Lighting Grid', 7.9, Icons.light, false),
  _Device('Auxiliary Load', 4.6, Icons.memory, false),
];

class PowerDeviceList extends StatelessWidget {
  const PowerDeviceList({super.key});

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
          Text('Device Breakdown',
              style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 16),
          ..._devices.map(_buildDevice),
        ],
      ),
    );
  }

  Widget _buildDevice(_Device d) {
    final pct = (d.kW / 22.4) * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: PowerTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(d.icon,
                    size: 16,
                    color: d.warning ? PowerTheme.danger : PowerTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(d.name,
                          overflow: TextOverflow.ellipsis,
                          style: PowerTextStyles.body(size: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: d.kW.toString(),
                            style: PowerTextStyles.mono(
                                size: 13, color: PowerTheme.textPrimary),
                          ),
                          TextSpan(
                            text: ' kW',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: PowerTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 5,
              backgroundColor: PowerTheme.surface,
              valueColor: AlwaysStoppedAnimation(
                  d.warning ? PowerTheme.danger : PowerTheme.lime),
            ),
          ),
        ],
      ),
    );
  }
}
