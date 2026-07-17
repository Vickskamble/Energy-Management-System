import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/power_theme.dart';

final _dailyData = [
  ('00:00', 42.0), ('02:00', 38.0), ('04:00', 35.0),
  ('06:00', 48.0), ('07:00', 58.0), ('08:00', 64.0),
  ('09:00', 66.0), ('10:00', 68.0), ('11:00', 67.0),
  ('12:00', 63.0), ('13:00', 60.0), ('14:00', 62.0),
  ('15:00', 65.0), ('16:00', 66.0), ('17:00', 62.0),
  ('18:00', 55.0), ('20:00', 48.0), ('22:00', 44.0),
];

final _weeklyData = [
  ('Mon', 420), ('Tue', 450), ('Wed', 395),
  ('Thu', 480), ('Fri', 440), ('Sat', 320), ('Sun', 290),
];

final _monthlyData = [
  ('Jan', 12500), ('Feb', 11800), ('Mar', 13200),
  ('Apr', 14100), ('May', 15200), ('Jun', 14800),
];

class ConsumptionScreen extends StatefulWidget {
  const ConsumptionScreen({super.key});

  @override
  State<ConsumptionScreen> createState() => _ConsumptionScreenState();
}

class _ConsumptionScreenState extends State<ConsumptionScreen> {
  String _period = 'day';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period toggle
          Row(
            children: ['day', 'week', 'month'].map((p) {
              final active = _period == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _period = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? PowerTheme.lime : PowerTheme.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PowerTheme.border),
                    ),
                    child: Text(
                      p[0].toUpperCase() + p.substring(1),
                      style: PowerTextStyles.body(
                        size: 13,
                        color: active ? PowerTheme.onLime : PowerTheme.textMuted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Main chart
          _buildChart(),
          const SizedBox(height: 20),

          // Summary stats
          Row(
            children: [
              _summaryCard('Peak Demand', _period == 'day'
                  ? '68.2 kW'
                  : _period == 'week' ? '480 kWh' : '15,200 kWh', Icons.trending_up),
              const SizedBox(width: 12),
              _summaryCard('Avg Load', _period == 'day'
                  ? '55.4 kW'
                  : _period == 'week' ? '395 kWh' : '13,600 kWh', Icons.analytics),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard('Total Cost', _period == 'day'
                  ? '₹3,210'
                  : _period == 'week' ? '₹22,400' : '₹89,500', Icons.currency_rupee),
              const SizedBox(width: 12),
              _summaryCard('PF Avg', '0.89', Icons.power),
            ],
          ),
          const SizedBox(height: 24),

          // Hourly breakdown table
          Text('Hourly Breakdown', style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 12),
          ...List.generate(12, (i) {
            final hr = 6 + i;
            final val = 35.0 + (i * 3.5) + (i == 5 ? 5 : 0);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PowerTheme.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('${hr.toString().padLeft(2, '0')}:00',
                        style: PowerTextStyles.body(size: 13, color: PowerTheme.textMuted)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: val / 70,
                        minHeight: 6,
                        backgroundColor: PowerTheme.surface,
                        valueColor: AlwaysStoppedAnimation(
                          val > 60 ? PowerTheme.danger : PowerTheme.lime),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      val.toStringAsFixed(1),
                      style: PowerTextStyles.mono(size: 12, color: PowerTheme.textPrimary),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('kW', style: TextStyle(fontSize: 10, color: PowerTheme.textMuted)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChart() {
    List<({String label, double value})> data;
    if (_period == 'day') {
      data = _dailyData.map((e) => (label: e.$1, value: e.$2)).toList();
    } else if (_period == 'week') {
      data = _weeklyData.map((e) => (label: e.$1, value: e.$2.toDouble())).toList();
    } else {
      data = _monthlyData.map((e) => (label: e.$1, value: e.$2.toDouble())).toList();
    }

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
          Text('Consumption Trend', style: PowerTextStyles.heading(size: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _period == 'day' ? 80 : _period == 'week' ? 600 : 18000,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _period == 'day' ? 20 : _period == 'week' ? 150 : 4500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: PowerTheme.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          meta.formattedValue,
                          style: PowerTextStyles.mono(size: 10, color: PowerTheme.textMuted),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx].label,
                            style: TextStyle(fontSize: 9, color: PowerTheme.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) {
                  final val = data[i].value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: val > (data.length > 10 ? 60 : 450)
                            ? PowerTheme.danger
                            : PowerTheme.lime,
                        width: _period == 'day' ? 8 : 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PowerTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PowerTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: PowerTheme.textMuted),
            const SizedBox(height: 8),
            Text(value,
                style: PowerTextStyles.mono(size: 16, color: PowerTheme.textPrimary)),
            Text(label,
                style: PowerTextStyles.body(size: 11, color: PowerTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
