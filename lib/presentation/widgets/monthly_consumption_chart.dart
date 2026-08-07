import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/energy_log_entity.dart';

class MonthlyConsumptionChart extends StatelessWidget {
  final List<EnergyLogEntity> logs;

  /// When set, shows per-day consumption for that month instead of the
  /// 12-month yearly view.
  final DateTime? selectedMonth;

  const MonthlyConsumptionChart({
    super.key,
    required this.logs,
    this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // ── Specific month selected → daily consumption for that month ──────
    if (selectedMonth != null) {
      final daily = <int, double>{};
      for (final log in logs) {
        if (log.loggedAt.year == selectedMonth!.year &&
            log.loggedAt.month == selectedMonth!.month) {
          daily.update(
            log.loggedAt.day,
            (v) => v + log.kwh * log.multiplyingFactor,
            ifAbsent: () => log.kwh * log.multiplyingFactor,
          );
        }
      }
      if (daily.isEmpty) {
        return const SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No consumption data for this month',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      }
      final daysInMonth = DateTime(
        selectedMonth!.year,
        selectedMonth!.month + 1,
        0,
      ).day;
      final spots = <FlSpot>[
        for (var d = 1; d <= daysInMonth; d++)
          FlSpot(
            d.toDouble(),
            daily.containsKey(d)
                ? (daily[d]! * 100).roundToDouble() / 100
                : 0,
          ),
      ];
      final maxConsumption = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
      final chartMaxY = (maxConsumption * 1.2).clamp(1.0, double.infinity);

      return SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 1,
            maxX: daysInMonth.toDouble(),
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
                    'Day',
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
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    final day = value.toInt();
                    if (day < 1 || day > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$day',
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
                        'Day ${spot.x.toInt()}: ${spot.y.toStringAsFixed(1)} kWh',
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

    final monthlyMap = <int, double>{};

    for (final log in logs) {
      if (log.loggedAt.year == now.year) {
        final month = log.loggedAt.month;
        monthlyMap.update(
          month,
          (v) => v + log.kwh * log.multiplyingFactor,
          ifAbsent: () => log.kwh * log.multiplyingFactor,
        );
      }
    }

    if (monthlyMap.isEmpty) {
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

    final months = List<double>.filled(12, 0);
    for (final entry in monthlyMap.entries) {
      months[entry.key - 1] = (entry.value * 100).roundToDouble() / 100;
    }

    final spots = <FlSpot>[
      for (int i = 0; i < 12; i++) FlSpot(i.toDouble(), months[i]),
    ];
    final maxConsumption = months.reduce((a, b) => a > b ? a : b);
    final chartMaxY = (maxConsumption * 1.2).clamp(1.0, double.infinity);

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
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
                  'Month (1-12)',
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
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt();
                  if (month < 1 || month > 12) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$month',
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
                      'Month ${spot.x.toInt() + 1}: ${spot.y.toStringAsFixed(1)} kWh',
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
}
