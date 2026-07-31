import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/energy_log_entity.dart';

class MonthlyConsumptionChart extends StatelessWidget {
  final List<EnergyLogEntity> logs;
  const MonthlyConsumptionChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dailyMap = <int, double>{};

    for (final log in logs) {
      if (log.loggedAt.year == now.year && log.loggedAt.month == now.month) {
        final day = log.loggedAt.day;
        dailyMap.update(
          day,
          (v) => v + log.kwh * AppConstants.multiplyingFactor,
          ifAbsent: () => log.kwh * AppConstants.multiplyingFactor,
        );
      }
    }

    if (dailyMap.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No monthly data',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final dayNumbers = dailyMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    double maxConsumption = 0;

    for (int i = 0; i < dayNumbers.length; i++) {
      final x = i.toDouble();
      final y = (dailyMap[dayNumbers[i]]! * 100).roundToDouble() / 100;
      spots.add(FlSpot(x, y));
      if (y > maxConsumption) maxConsumption = y;
    }

    final chartMaxY = (maxConsumption * 1.2).clamp(1.0, double.infinity);

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (dayNumbers.length - 1).toDouble().clamp(0, double.infinity),
          minY: 0,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (chartMaxY / 4).ceilToDouble().clamp(
              1,
              double.infinity,
            ),
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.borderLight, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: RotatedBox(
                quarterTurns: -1,
                child: Text(
                  'kWh',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              axisNameSize: 26,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${value.toInt()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Day of Month',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              axisNameSize: 22,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _bottomInterval(dayNumbers.length),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dayNumbers.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${dayNumbers[idx]}',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map(
                    (spot) => LineTooltipItem(
                      'Day ${dayNumbers[spot.spotIndex.toInt()]}: ${spot.y.toStringAsFixed(1)} kWh',
                      TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 15) return 2;
    if (count <= 25) return 4;
    return (count / 6).ceilToDouble();
  }
}
