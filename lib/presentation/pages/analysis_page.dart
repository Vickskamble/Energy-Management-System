import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/insights/insight_generator.dart';
import '../../core/recommendations/recommendation_engine.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnergyBloc, EnergyState>(
      builder: (context, state) {
        return switch (state) {
          EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(
            message: 'Loading data...',
          ),
          EnergySuccess(:final logs) => _AnalysisContent(logs: logs),
          EnergyValidationError _ => Center(child: Text(state.message)),
          EnergyOperationFailure _ => Center(child: Text(state.message)),
        };
      },
    );
  }
}

class _AnalysisContent extends StatelessWidget {
  final List<dynamic> logs;
  const _AnalysisContent({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const AppEmptyState(
        icon: Icons.analytics_rounded,
        title: 'No readings recorded yet',
        subtitle: 'Add readings to see analysis',
      );
    }

    final entities = logs.cast<EnergyLogEntity>();
    final breakdown = BillCalculator.calculate(logs: entities);
    final kpis = BillCalculator.calculateKpis(breakdown);
    final insights = InsightGenerator.generate(
      breakdown: breakdown,
      comparison: null,
      kpis: kpis,
      logs: entities,
    );
    final recommendations = RecommendationEngine.generate(
      breakdown: breakdown,
      comparison: null,
      logs: entities,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppSectionHeader(
            title: 'Bill Analysis',
            subtitle: 'Detailed analysis of your energy data',
          ),

          AppCard(
            child: Column(
              children: [
                _kpiRow(
                  'Bill Health',
                  '${kpis.billHealthScore.toStringAsFixed(0)}/100',
                  kpis.billHealthScore >= 80
                      ? AppColors.success
                      : AppColors.warning,
                  'Energy Score',
                  '${kpis.energyScore.toStringAsFixed(0)}/100',
                  kpis.energyScore >= 80
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(height: 12),
                _kpiRow(
                  'Net Bill',
                  '₹${breakdown.netBill.toStringAsFixed(0)}',
                  AppColors.kpiCost,
                  'Avg Unit Cost',
                  '₹${breakdown.averageUnitCost.toStringAsFixed(2)}/kWh',
                  AppColors.kpiCost,
                ),
                const SizedBox(height: 12),
                _kpiRow(
                  'Power Factor',
                  breakdown.powerFactor.toStringAsFixed(3),
                  AppColors.kpiPower,
                  'Load Factor',
                  '${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
                  breakdown.loadFactor >= 0.75
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (insights.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Smart Insights',
              subtitle: 'Business meaning of your metrics',
            ),
            ...insights
                .take(4)
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InsightCard(insight: i),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (recommendations.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Recommendations',
              subtitle: 'Based on your data',
            ),
            ...recommendations.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RecommendationCard(rec: r),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          AppSectionHeader(title: 'Reading History'),
          _buildLogList(entities),
        ],
      ),
    );
  }

  Widget _kpiRow(
    String label1,
    String value1,
    Color color1,
    String label2,
    String value2,
    Color color2,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label2,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value2,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogList(List<EnergyLogEntity> entities) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      children: entities
          .map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            log.isSynced
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            size: 18,
                            color: log.isSynced
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.meterName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                dateFmt.format(log.loggedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (log.isSynced
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.isSynced ? 'Cloud' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: log.isSynced
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        _dataCell(
                          'kWh',
                          log.kwh.toStringAsFixed(1),
                          AppColors.kpiEnergy,
                        ),
                        _dataCell(
                          'PF',
                          log.powerFactor.toStringAsFixed(3),
                          AppColors.kpiPower,
                        ),
                        _dataCell(
                          'MD (kW)',
                          log.mdRecorded.toStringAsFixed(1),
                          AppColors.kpiDemand,
                        ),
                        _dataCell(
                          'Bill',
                          '₹ ${log.estimatedBill.toStringAsFixed(0)}',
                          AppColors.kpiCost,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _dataCell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final InsightItem insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = switch (insight.severity) {
      InsightSeverity.positive => (
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      InsightSeverity.neutral => (Icons.info_rounded, AppColors.primary),
      InsightSeverity.warning => (
        Icons.warning_amber_rounded,
        AppColors.warning,
      ),
      InsightSeverity.critical => (Icons.error_rounded, AppColors.danger),
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (insight.recommendation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          insight.recommendation!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final RecommendationItem rec;
  const _RecommendationCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  rec.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (rec.estimatedSavings != null &&
                    rec.estimatedSavings! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.savings_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Potential savings: ₹${rec.estimatedSavings!.toStringAsFixed(0)}/month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
