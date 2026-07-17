import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/power_theme.dart';

final _data = [
  ('00:00', 42.0), ('02:00', 38.0), ('04:00', 35.0),
  ('06:00', 48.0), ('07:00', 58.0), ('08:00', 64.0),
  ('09:00', 66.0), ('10:00', 68.0), ('11:00', 67.0),
  ('12:00', 63.0), ('13:00', 60.0), ('14:00', 62.0),
  ('15:00', 65.0), ('16:00', 66.0), ('17:00', 62.0),
  ('18:00', 55.0), ('20:00', 48.0), ('22:00', 44.0),
];

final _weekData = [
  ('Mon', 58.0), ('Tue', 62.0), ('Wed', 55.0),
  ('Thu', 65.0), ('Fri', 60.0), ('Sat', 45.0), ('Sun', 42.0),
];

class PowerConsumptionChart extends StatefulWidget {
  const PowerConsumptionChart({super.key});

  @override
  State<PowerConsumptionChart> createState() => _PowerConsumptionChartState();
}

class _PowerConsumptionChartState extends State<PowerConsumptionChart> {
  bool _isToday = true;

  @override
  Widget build(BuildContext context) {
    final data = _isToday ? _data : _weekData;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consumption Trend',
                  style: PowerTextStyles.heading(size: 16)),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: PowerTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PowerTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Today', 'Week'].map((r) {
                    final active = (r == 'Today') == _isToday;
                    return GestureDetector(
                      onTap: () => setState(() => _isToday = r == 'Today'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? PowerTheme.lime : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r,
                          style: PowerTextStyles.body(
                            size: 11,
                            color: active
                                ? PowerTheme.onLime
                                : PowerTheme.textMuted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 10,
                  drawVerticalLine: false,
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
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            meta.formattedValue,
                            style: PowerTextStyles.mono(
                              size: 10,
                              color: PowerTheme.textMuted,
                              weight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _isToday ? 4 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx].$1,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: PowerTheme.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(data.length,
                        (i) => FlSpot(i.toDouble(), data[i].$2)),
                    isCurved: true,
                    color: PowerTheme.lime,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          PowerTheme.lime.withAlpha(80),
                          PowerTheme.lime.withAlpha(5),
                        ],
                      ),
                    ),

                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => PowerTheme.white,
                    tooltipBorder: BorderSide(color: PowerTheme.border),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} kW',
                          TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: PowerTheme.textPrimary,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
