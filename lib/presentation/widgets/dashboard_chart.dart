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
    final kwhSpots = <FlSpot>[];
    final mdSpots = <FlSpot>[];
    double maxKwh = 0;
    double maxMd = 0;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final x = i.toDouble();
      kwhSpots.add(FlSpot(x, log.kwh));
      mdSpots.add(FlSpot(x, log.mdRecorded));
      if (log.kwh > maxKwh) maxKwh = log.kwh;
      if (log.mdRecorded > maxMd) maxMd = log.mdRecorded;
    }

    final contractDemand = AppConstants.defaultContractDemandKva;
    final kwhMaxY = maxKwh * 1.2;
    final mdMaxY = (maxMd > contractDemand ? maxMd : contractDemand) * 1.2;
    final maxX = (sorted.length - 1).toDouble().clamp(0, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(AppColors.primary, 'Consumption (kWh)'),
            const SizedBox(width: 16),
            _legendItem(AppColors.warning, 'Max Demand (kVA)'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              _kwhChart(sorted, kwhSpots, mdSpots, kwhMaxY, maxX),
              IgnorePointer(
                child: _mdChart(mdSpots, mdMaxY, maxX, contractDemand),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kwhChart(
    List<EnergyLogEntity> sorted,
    List<FlSpot> kwhSpots,
    List<FlSpot> mdSpots,
    double kwhMaxY,
    double maxX,
  ) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: kwhMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _axisInterval(kwhMaxY),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.borderLight, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: _axisTitles(isRight: false, maxY: kwhMaxY),
          bottomTitles: _bottomTitles(sorted),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [_line(spots: kwhSpots, color: AppColors.primary)],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.expand((spot) {
              final idx = spot.x.toInt();
              final mdValue = (idx >= 0 && idx < mdSpots.length)
                  ? mdSpots[idx].y
                  : null;
              return [
                LineTooltipItem(
                  'kWh: ${spot.y.toStringAsFixed(1)}',
                  TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (mdValue != null)
                  LineTooltipItem(
                    'kVA: ${mdValue.toStringAsFixed(1)}',
                    TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ];
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _mdChart(
    List<FlSpot> mdSpots,
    double mdMaxY,
    double maxX,
    double contractDemand,
  ) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: mdMaxY,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: _axisTitles(isRight: true, maxY: mdMaxY),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [_line(spots: mdSpots, color: AppColors.warning)],
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
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  AxisTitles _axisTitles({required bool isRight, required double maxY}) {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        getTitlesWidget: (value, meta) {
          if (value == meta.max) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(
              right: isRight ? 0 : 4,
              left: isRight ? 4 : 0,
            ),
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
    );
  }

  AxisTitles _bottomTitles(List<EnergyLogEntity> sorted) {
    return AxisTitles(
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

  LineChartBarData _line({required List<FlSpot> spots, required Color color}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  double _axisInterval(double maxY) =>
      (maxY / 4).ceilToDouble().clamp(1, double.infinity);

  double _bottomInterval(int count) {
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    if (count <= 20) return 4;
    return (count / 5).ceilToDouble();
  }
}
