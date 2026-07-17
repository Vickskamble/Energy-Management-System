import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';
import '../../widgets/power/power_stat_card.dart';
import '../../widgets/power/power_consumption_chart.dart';
import '../../widgets/power/power_device_list.dart';
import '../../widgets/power/power_alerts_list.dart';
import 'consumption_screen.dart';
import 'devices_screen.dart';
import 'billing_screen.dart';
import 'alerts_screen.dart';

class PowerDashboard extends StatefulWidget {
  const PowerDashboard({super.key});

  @override
  State<PowerDashboard> createState() => _PowerDashboardState();
}

class _PowerDashboardState extends State<PowerDashboard> {
  int _currentTab = 0;

  final _tabs = [
    ('Overview', Icons.dashboard_outlined, Icons.dashboard),
    ('Consumption', Icons.bar_chart_outlined, Icons.bar_chart),
    ('Devices', Icons.memory_outlined, Icons.memory),
    ('Billing', Icons.receipt_outlined, Icons.receipt),
    ('Alerts', Icons.notifications_outlined, Icons.notifications),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PowerTheme.white,
      appBar: AppBar(
        backgroundColor: PowerTheme.lime,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: PowerTheme.onLime.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.bolt, size: 16, color: PowerTheme.onLime),
            ),
            const SizedBox(width: 10),
            Text(
              'Power',
              style: PowerTextStyles.heading(
                size: 18,
                color: PowerTheme.onLime,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: PowerTheme.onLime.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: PowerTheme.onLime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: PowerTextStyles.body(
                    size: 10,
                    color: PowerTheme.onLime,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                size: 20, color: PowerTheme.onLime),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: PowerTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          backgroundColor: PowerTheme.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: PowerTheme.lime,
          unselectedItemColor: PowerTheme.textMuted,
          selectedLabelStyle: PowerTextStyles.body(
            size: 11,
            color: PowerTheme.lime,
            weight: FontWeight.w600,
          ),
          unselectedLabelStyle: PowerTextStyles.body(
            size: 11,
            color: PowerTheme.textMuted,
          ),
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.$2),
                    activeIcon: Icon(t.$3),
                    label: t.$1,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stat cards
          PowerStatCard(
            label: 'Current Load',
            value: '65.9',
            unit: 'kW',
            delta: '+4.2% vs avg',
            isLime: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: PowerStatCard(
                  label: "Today's Usage",
                  value: '428',
                  unit: 'kWh',
                  delta: '-6.1% vs yesterday',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: PowerStatCard(
                  label: 'Est. Cost Today',
                  value: '₹3,210',
                  delta: '+2.8%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const PowerStatCard(
            label: 'Efficiency Score',
            value: '82',
            unit: '/100',
            delta: '+3 pts',
          ),
          const SizedBox(height: 20),
          // Chart
          const PowerConsumptionChart(),
          const SizedBox(height: 16),
          // Device list
          const PowerDeviceList(),
          const SizedBox(height: 16),
          // Alerts
          const PowerAlertsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0: return _buildOverview();
      case 1: return const ConsumptionScreen();
      case 2: return const DevicesScreen();
      case 3: return const BillingScreen();
      case 4: return const AlertsScreen();
      default: return const SizedBox.shrink();
    }
  }
}
