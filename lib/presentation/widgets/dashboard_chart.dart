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
    if (logs.isEmpty) {
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

    final sorted = List<EnergyLogEntity>.from(logs)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final mdSpots = <FlSpot>[];
    double maxMd = 0;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final x = i.toDouble();
      mdSpots.add(FlSpot(x, log.mdRecorded));
      if (log.mdRecorded > maxMd) maxMd = log.mdRecorded;
    }

    final contractDemand = AppConstants.defaultContractDemandKva;
    final mdMaxY = (maxMd > contractDemand ? maxMd : contractDemand) * 1.2;
    final maxX = (sorted.length - 1)
        .toDouble()
        .clamp(0, double.infinity)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(AppColors.warning, 'Max Demand (kVA)'),
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
              maxX: maxX,
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
                bottomTitles: _bottomTitles(sorted),
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
                  spots: mdSpots,
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
                      'kVA: ${spot.y.toStringAsFixed(1)}',
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

  AxisTitles _bottomTitles(List<EnergyLogEntity> sorted) {
    return AxisTitles(
      axisNameWidget: _axisLabel('Date (day/hour)'),
      axisNameSize: 22,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: _bottomInterval(sorted.length),
        getTitlesWidget: (value, meta) {
          final idx = value.toInt();
          if (idx < 0 || idx >= sorted.length) {
            return const SizedBox.shrink();
          }
          final date = sorted[idx].loggedAt;
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${date.day}/${date.hour}h',
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

  double _bottomInterval(int count) {
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    if (count <= 20) return 4;
    return (count / 5).ceilToDouble();
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
