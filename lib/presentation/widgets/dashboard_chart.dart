import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/energy_log_entity.dart';

class DashboardChart extends StatelessWidget {
  final List<EnergyLogEntity> logs;
  const DashboardChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthlySum = <int, double>{};
    final monthlyCount = <int, int>{};

    for (final log in logs) {
      if (log.loggedAt.year == now.year) {
        final month = log.loggedAt.month;
        monthlySum.update(
          month,
          (v) => v + log.mdRecorded,
          ifAbsent: () => log.mdRecorded,
        );
        monthlyCount.update(month, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    if (monthlySum.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No data available for chart',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final avgPerMonth = List<double>.filled(12, 0);
    for (final entry in monthlySum.entries) {
      avgPerMonth[entry.key - 1] =
          ((entry.value / monthlyCount[entry.key]!) * 100).roundToDouble() /
          100;
    }

    final spots = <FlSpot>[
      for (int i = 0; i < 12; i++) FlSpot(i.toDouble(), avgPerMonth[i]),
    ];

    final contractDemand = AppConstants.defaultContractDemandKva;
    final maxAvg = avgPerMonth.reduce((a, b) => a > b ? a : b);
    final mdMaxY = (maxAvg > contractDemand ? maxAvg : contractDemand) * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(AppColors.warning, 'Avg Demand (kVA)'),
            const SizedBox(width: 16),
            _dashedLegendItem(AppColors.danger, 'Contract Demand'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY: mdMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (mdMaxY / 4).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: AppColors.borderLight, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: _axisLabel('kVA', vertical: true),
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
                bottomTitles: _bottomTitles(),
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
                  curveSmoothness: 0.25,
                  color: AppColors.warning,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.warning.withValues(alpha: 0.08),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: contractDemand,
                    color: AppColors.danger,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      labelResolver: (_) =>
                          'Contract Demand (${contractDemand.toInt()} kVA)',
                    ),
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    return LineTooltipItem(
                      'Month ${spot.x.toInt() + 1}: '
                      'Avg Demand ${spot.y.toStringAsFixed(1)} kVA',
                      TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  AxisTitles _bottomTitles() {
    return AxisTitles(
      axisNameWidget: _axisLabel('Month (1-12)'),
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
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          );
        },
      ),
    );
  }

  Widget _axisLabel(String text, {bool vertical = false}) {
    final label = Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
    return vertical
        ? RotatedBox(quarterTurns: -1, child: label)
        : Padding(padding: const EdgeInsets.only(top: 4), child: label);
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _dashedLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(18, 4), painter: _DashPainter(color)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
