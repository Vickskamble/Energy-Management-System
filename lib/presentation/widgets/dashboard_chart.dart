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
      return const SizedBox(height: 220, child: Center(child: Text('No data available for chart', style: TextStyle(color: AppColors.textSecondary))));
    }

    final sorted = List<EnergyLogEntity>.from(logs)..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final kwhSpots = <FlSpot>[];
    final mdSpots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final x = i.toDouble();
      kwhSpots.add(FlSpot(x, log.kwh));
      mdSpots.add(FlSpot(x, log.mdRecorded));
      if (log.kwh > maxY) maxY = log.kwh;
      if (log.mdRecorded > maxY) maxY = log.mdRecorded;
    }

    final contractDemand = AppConstants.defaultContractDemandKva;
    final chartMaxY = (maxY > contractDemand ? maxY : contractDemand) * 1.15;

    return SizedBox(
      height: 260,
      child: LineChart(LineChartData(
        minX: 0, maxX: (sorted.length - 1).toDouble().clamp(0, double.infinity), minY: 0, maxY: chartMaxY,
        gridData: FlGridData(show: true, drawVerticalLine: false,
          horizontalInterval: (chartMaxY / 4).ceilToDouble().clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.borderLight, strokeWidth: 1)),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
            getTitlesWidget: (value, meta) {
              if (value == meta.max) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(right: 4),
                child: Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'JetBrains Mono')));
            })),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
            interval: _bottomInterval(sorted.length),
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= sorted.length) return const SizedBox.shrink();
              final date = sorted[idx].loggedAt;
              return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('${date.day}/${date.hour}h', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)));
            })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _line(spots: kwhSpots, color: AppColors.primary),
          _line(spots: mdSpots, color: AppColors.warning),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: contractDemand, color: AppColors.danger, strokeWidth: 1.5, dashArray: [6, 4],
            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight,
              style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w500),
              labelResolver: (_) => 'Contract Demand (${contractDemand.toInt()} kVA)')),
        ]),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            final isKwh = spot.barIndex == 0;
            return LineTooltipItem('${isKwh ? 'kWh' : 'kVA'}: ${spot.y.toStringAsFixed(1)}',
              TextStyle(color: isKwh ? AppColors.primary : AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12));
          }).toList(),
        )),
      )),
    );
  }

  LineChartBarData _line({required List<FlSpot> spots, required Color color}) {
    return LineChartBarData(spots: spots, isCurved: true, curveSmoothness: 0.25, color: color, barWidth: 2.5, isStrokeCapRound: true,
      dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)));
  }

  double _bottomInterval(int count) {
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    if (count <= 20) return 4;
    return (count / 5).ceilToDouble();
  }
}
