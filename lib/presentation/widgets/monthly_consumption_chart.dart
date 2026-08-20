import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/energy_log_entity.dart';

class MonthlyConsumptionChart extends StatelessWidget {
  final List<EnergyLogEntity> logs;

  /// Called with the tapped 1-based month of the chart's max year.
  final ValueChanged<int>? onMonthTap;

  /// Client's daily avg kWh target — draws a dashed "target × days of month"
  /// cross line. 0 = no line.
  final double targetKwhPerDay;

  const MonthlyConsumptionChart({
    super.key,
    required this.logs,
    this.onMonthTap,
    this.targetKwhPerDay = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = onMonthTap;
    final monthlyMap = <int, double>{};
    final dim = AppColors.dim(context);
    final line = AppColors.line(context);

    if (logs.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 30,
                color: dim,
              ),
              const SizedBox(height: 8),
              Text(
                'No monthly data',
                style: TextStyle(color: dim),
              ),
            ],
          ),
        ),
      );
    }

    final maxYear = logs
        .map((l) => l.loggedAt.year)
        .reduce((a, b) => a > b ? a : b);
    for (final log in logs) {
      if (log.loggedAt.year == maxYear) {
        final month = log.loggedAt.month;
        monthlyMap.update(
          month,
          (v) => v + log.kwh * log.multiplyingFactor,
          ifAbsent: () => log.kwh * log.multiplyingFactor,
        );
      }
    }

    if (monthlyMap.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 30,
                color: dim,
              ),
              const SizedBox(height: 8),
              Text(
                'No monthly data',
                style: TextStyle(color: dim),
              ),
            ],
          ),
        ),
      );
    }

    final entries = monthlyMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[
      for (final entry in entries)
        FlSpot(
          (entry.key - 1).toDouble(),
          (entry.value * 100).roundToDouble() / 100,
        ),
    ];
    final maxConsumption = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
    var chartMaxY = (maxConsumption * 1.2).clamp(1.0, double.infinity);

    // Dashed cross line = daily target × days in each month, so a monthly
    // bar crossing it means the client exceeded the daily avg budget.
    final targetSpots = <FlSpot>[];
    if (targetKwhPerDay > 0) {
      for (var m = 1; m <= 12; m++) {
        final days = DateTime(maxYear, m + 1, 0).day;
        final y = targetKwhPerDay * days;
        targetSpots.add(FlSpot((m - 1).toDouble(), y));
        if (y > chartMaxY) chartMaxY = y;
      }
      chartMaxY = chartMaxY * 1.05;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (targetSpots.isNotEmpty) ...[
          _targetLegend(dim),
          const SizedBox(height: 8),
        ],
        SizedBox(
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
                FlLine(color: line, strokeWidth: 1),
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
                    color: dim,
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
                        color: dim,
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
                    color: dim,
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
                        color: dim,
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
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: AppColors.primary,
                      strokeWidth: 1,
                      strokeColor: AppColors.primary,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            if (targetSpots.isNotEmpty)
              LineChartBarData(
                spots: targetSpots,
                isCurved: false,
                color: AppColors.danger,
                barWidth: 1.5,
                dashArray: [6, 4],
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchCallback:
                onTap == null
                    ? null
                    : (event, response) {
                        if (event is FlTapUpEvent &&
                            response != null &&
                            response.lineBarSpots != null &&
                            response.lineBarSpots!.isNotEmpty) {
                          final month = response.lineBarSpots!.first.x
                                  .toInt() +
                              1;
                          if (monthlyMap.containsKey(month)) {
                            onTap(month);
                          }
                        }
                      },
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
      ),
        ],
    );
  }

  Widget _targetLegend(Color dim) {
    return Row(
      children: [
        CustomPaint(
          size: const Size(18, 4),
          painter: _DashPainter(AppColors.danger),
        ),
        const SizedBox(width: 6),
        Text(
          'Daily target × days '
          '(${targetKwhPerDay.toStringAsFixed(0)} kWh/day)',
          style: TextStyle(
            fontSize: 11,
            color: dim,
          ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 4.0;
    const gap = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0.0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}
