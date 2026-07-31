import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_kpi_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/calculation/bill_forecast.dart';
import '../../core/calculation/savings_opportunity.dart';
import '../../core/insights/insight_generator.dart';
import '../../core/recommendations/recommendation_engine.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';
import '../widgets/dashboard_chart.dart';
import '../widgets/monthly_consumption_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyBloc, EnergyState>(
      listener: (context, state) {
        if (state is EnergySuccess) {
          if (state.currentPowerFactor < AppConstants.pfPenaltyThreshold) {
            NotificationService.instance.showPfAlert(state.currentPowerFactor);
          }
          if (state.maxDemandPeak >= AppConstants.mdWarningThresholdKva) {
            NotificationService.instance.showMdAlert(
              state.maxDemandPeak,
              AppConstants.defaultContractDemandKva,
            );
          }
        }
      },
      child: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          return switch (state) {
            EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(
              message: 'Loading dashboard...',
            ),
            EnergySuccess(
              :final logs,
              :final estimatedBill,
              :final totalConsumption,
              :final activeConsumptionToday,
              :final currentPowerFactor,
              :final maxDemandPeak,
            ) =>
              _DashboardContent(
                logs: logs,
                estimatedBill: estimatedBill,
                totalConsumption: totalConsumption,
                activeConsumptionToday: activeConsumptionToday,
                currentPowerFactor: currentPowerFactor,
                maxDemandPeak: maxDemandPeak,
              ),
            EnergyValidationError e => AppErrorState(
              message: e.message,
              onRetry: () => context.read<EnergyBloc>().add(
                const LoadInitialDashboardData(),
              ),
            ),
            EnergyOperationFailure e => AppErrorState(
              message: e.message,
              onRetry: () => context.read<EnergyBloc>().add(
                const LoadInitialDashboardData(),
              ),
            ),
          };
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<dynamic> logs;
  final double estimatedBill;
  final double totalConsumption;
  final double activeConsumptionToday;
  final double currentPowerFactor;
  final double maxDemandPeak;

  const _DashboardContent({
    required this.logs,
    required this.estimatedBill,
    required this.totalConsumption,
    required this.activeConsumptionToday,
    required this.currentPowerFactor,
    required this.maxDemandPeak,
  });

  @override
  Widget build(BuildContext context) {
    final entityLogs = logs.cast<EnergyLogEntity>();
    final breakdown = BillCalculator.calculate(logs: entityLogs);
    final kpis = BillCalculator.calculateKpis(breakdown);
    final now = DateTime.now();
    final currentMonthLogs = entityLogs
        .where(
          (l) => l.loggedAt.year == now.year && l.loggedAt.month == now.month,
        )
        .toList();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousMonthLogs = entityLogs
        .where(
          (l) =>
              l.loggedAt.year == previousMonth.year &&
              l.loggedAt.month == previousMonth.month,
        )
        .toList();
    final currentMonthBreakdown = currentMonthLogs.isEmpty
        ? null
        : BillCalculator.calculate(logs: currentMonthLogs);
    final previousBreakdown = previousMonthLogs.isEmpty
        ? null
        : BillCalculator.calculate(logs: previousMonthLogs);
    final comparison = currentMonthBreakdown == null
        ? null
        : BillCalculator.compare(currentMonthBreakdown, previousBreakdown);
    final forecast = BillForecastCalculator.calculate(
      monthLogs: currentMonthLogs,
    );
    final opportunities = SavingOpportunityGenerator.generate(breakdown);
    final insights = InsightGenerator.generate(
      breakdown: breakdown,
      comparison: comparison,
      kpis: kpis,
      logs: entityLogs,
    );
    final recommendations = RecommendationEngine.generate(
      breakdown: breakdown,
      comparison: null,
      logs: entityLogs,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppSectionHeader(
            title: 'Energy Overview',
            subtitle: 'Bill analysis and monitoring dashboard',
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildAlertsSection(context),
          const SizedBox(height: AppSpacing.xl),

          _kpiGrid(
            cards: [
              AppKpiCard(
                title: 'Est. Monthly Bill',
                value: estimatedBill,
                suffix: '₹',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.kpiCost,
                decimals: 0,
                description:
                    'Avg unit cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
              ),
              AppKpiCard(
                title: 'Total Consumption',
                value: totalConsumption,
                suffix: 'kWh',
                icon: Icons.bolt_rounded,
                color: AppColors.kpiEnergy,
                decimals: 0,
                description:
                    '${breakdown.totalUnits.toStringAsFixed(0)} billed units',
              ),
              AppKpiCard(
                title: 'Max Demand',
                value: maxDemandPeak,
                suffix: 'kVA',
                icon: Icons.trending_up_rounded,
                color: maxDemandPeak >= AppConstants.mdWarningThresholdKva
                    ? AppColors.warning
                    : AppColors.kpiDemand,
                description:
                    'Billing demand: ${breakdown.billingDemand.toStringAsFixed(1)} kVA',
              ),
              AppKpiCard(
                title: 'Power Factor',
                value: currentPowerFactor,
                suffix: 'PF',
                icon: Icons.waves_rounded,
                color: currentPowerFactor < AppConstants.pfPenaltyThreshold
                    ? AppColors.danger
                    : AppColors.kpiPower,
                decimals: 3,
                description:
                    currentPowerFactor >= AppConstants.pfRebateThreshold
                    ? 'Rebate earned'
                    : (currentPowerFactor >= AppConstants.pfSurchargeThreshold
                          ? 'Near rebate'
                          : 'Penalty applies'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _kpiGrid(
            cards: [
              AppKpiCard(
                title: 'Bill Health Score',
                value: kpis.billHealthScore,
                suffix: '/100',
                icon: Icons.health_and_safety_rounded,
                color: kpis.billHealthScore >= 80
                    ? AppColors.kpiEfficiency
                    : (kpis.billHealthScore >= 60
                          ? AppColors.warning
                          : AppColors.danger),
                decimals: 0,
                description: kpis.billHealthScore >= 80
                    ? 'Good — all parameters optimized'
                    : kpis.billHealthScore >= 60
                    ? 'Needs attention'
                    : 'Critical issues',
              ),
              AppKpiCard(
                title: 'Load Factor',
                value: breakdown.loadFactor * 100,
                suffix: '%',
                icon: Icons.speed_rounded,
                color:
                    breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
                    ? AppColors.kpiEfficiency
                    : AppColors.warning,
                decimals: 0,
                description:
                    breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
                    ? 'Efficient usage'
                    : 'Improve load smoothing',
              ),
              AppKpiCard(
                title: "Today's Usage",
                value: activeConsumptionToday,
                suffix: 'kWh',
                icon: Icons.today_rounded,
                color: AppColors.kpiSavings,
                description: 'Consumption so far today',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          if (opportunities.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Bill Saving Opportunities',
              subtitle: 'Direct monthly savings — priority order me',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < opportunities.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _SavingOpportunityCard(
                      opportunity: opportunities[i],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demand Trend (kVA)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: DashboardChart(logs: entityLogs),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Consumption',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: MonthlyConsumptionChart(logs: entityLogs),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildComparisonCard(comparison)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildForecastCard(forecast)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (breakdown.netBill > 0)
                Expanded(
                  flex: 3,
                  child: _buildBillBreakdown(context, breakdown),
                ),
              if (breakdown.netBill > 0 && insights.isNotEmpty)
                const SizedBox(width: AppSpacing.lg),
              if (insights.isNotEmpty)
                Expanded(flex: 2, child: _buildInsightsSection(insights)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (recommendations.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Recommendations',
              subtitle: 'Actionable steps to reduce your bill',
            ),
            ...recommendations
                .take(3)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecommendationCard(rec: r),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid({required List<Widget> cards}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing * 3) / 4;
        return GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: cardWidth / 200,
          children: cards,
        );
      },
    );
  }

  Widget _buildInsightsSection(List<InsightItem> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Smart Insights',
          subtitle: 'What these numbers mean for your business',
        ),
        ...insights
            .take(4)
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightCard(insight: i),
              ),
            ),
      ],
    );
  }

  Widget _buildComparisonCard(MonthComparison? comparison) {
    return AppCard(
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
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Month Comparison',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (comparison != null && comparison.isBillDecreased)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.savings_rounded,
                        size: 12,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Saved ₹${comparison.billDifference.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (comparison == null || comparison.current.netBill <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Is month abhi tak koi reading nahi',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            _comparisonRow(
              label: 'Est. Bill',
              value: '₹${comparison.current.netBill.toStringAsFixed(0)}',
              chipText: comparison.previous == null
                  ? 'first month'
                  : '${comparison.billDifference >= 0 ? '↑' : '↓'} ${comparison.billPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.billDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Consumption',
              value: '${comparison.current.totalUnits.toStringAsFixed(0)} kWh',
              chipText: comparison.previous == null
                  ? 'first month'
                  : '${comparison.unitDifference >= 0 ? '↑' : '↓'} ${comparison.unitPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.unitDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Max Demand',
              value:
                  '${comparison.current.billingDemand.toStringAsFixed(1)} kVA',
              chipText: comparison.previous == null
                  ? 'first month'
                  : '${comparison.demandDifference >= 0 ? '↑' : '↓'} ${comparison.demandPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.demandDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Power Factor',
              value: comparison.current.powerFactor.toStringAsFixed(3),
              chipText: comparison.previous == null
                  ? 'first month'
                  : 'vs ${comparison.previous!.powerFactor.toStringAsFixed(3)}',
              isGood: comparison.pfDifference >= 0,
              chipNeutral: comparison.previous == null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonRow({
    required String label,
    required String value,
    required String chipText,
    required bool isGood,
    bool chipNeutral = false,
  }) {
    final chipColor = chipNeutral
        ? AppColors.textSecondary
        : (isGood ? AppColors.success : AppColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(BillForecast? forecast) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.kpiCost.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: AppColors.kpiCost,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Bill Forecast',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (forecast == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Is month abhi tak koi reading nahi',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              'Projected Month-End Bill',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${forecast.projectedBill.toStringAsFixed(0)}',
              style: AppTypography.mono(
                size: 28,
                weight: FontWeight.w700,
                color: AppColors.kpiCost,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '≈ ${forecast.projectedUnits.toStringAsFixed(0)} kWh units',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            Row(
              children: [
                _forecastStat(
                  'Avg / day',
                  '₹${forecast.dailyAverageBill.toStringAsFixed(0)}',
                ),
                _forecastStat(
                  'Days left',
                  '${forecast.daysInMonth - forecast.daysElapsed}',
                ),
                _forecastStat(
                  'Progress',
                  '${(forecast.daysElapsed / forecast.daysInMonth * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: forecast.daysElapsed / forecast.daysInMonth,
                minHeight: 6,
                color: AppColors.kpiCost,
                backgroundColor: AppColors.kpiCost.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aaj ki usage rate par estimated — readings badhne par update hoga',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _forecastStat(String label, String value) {
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBillBreakdown(BuildContext context, BillBreakdown breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Bill Breakdown',
          subtitle:
              '₹${breakdown.netBill.toStringAsFixed(0)} total estimated bill',
        ),
        AppCard(
          child: Column(
            children: [
              _billRow(
                'Energy Charges',
                breakdown.energyCharges,
                breakdown.energyChargesPercent,
                AppColors.kpiEnergy,
              ),
              const Divider(height: 24),
              _billRow(
                'Demand Charges',
                breakdown.demandCharges,
                breakdown.demandChargesPercent,
                AppColors.kpiDemand,
              ),
              const Divider(height: 24),
              _billRow(
                'FAC',
                breakdown.facCharges,
                breakdown.facPercent,
                AppColors.warning,
              ),
              const Divider(height: 24),
              _billRow(
                'Wheeling Charges',
                breakdown.wheelingCharges,
                breakdown.wheelingPercent,
                AppColors.textSecondary,
              ),
              const Divider(height: 24),
              _billRow(
                'Electricity Duty',
                breakdown.electricityDuty,
                breakdown.dutyPercent,
                AppColors.kpiEfficiency,
              ),
              const Divider(height: 24),
              _billRow(
                'Taxes',
                breakdown.taxes,
                breakdown.taxesPercent,
                AppColors.kpiCO2,
              ),
              if (breakdown.pfRebate > 0) ...[
                const Divider(height: 24),
                _billRow(
                  'PF Rebate',
                  -breakdown.pfRebate,
                  0,
                  AppColors.success,
                ),
              ],
              if (breakdown.pfSurcharge > 0) ...[
                const Divider(height: 24),
                _billRow(
                  'PF Surcharge',
                  breakdown.pfSurcharge,
                  0,
                  AppColors.danger,
                ),
              ],
              if (breakdown.subsidy > 0) ...[
                const Divider(height: 24),
                _billRow('Subsidy', -breakdown.subsidy, 0, AppColors.success),
              ],
              const Divider(height: 24),
              _billRow(
                'Net Bill',
                breakdown.netBill,
                100,
                AppColors.primary,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _billRow(
    String label,
    double amount,
    double percent,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (percent > 0)
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        const SizedBox(width: 16),
        Text(
          '₹${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: amount >= 0 ? null : AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final hasPfIssue = currentPowerFactor < AppConstants.pfPenaltyThreshold;
    final hasMdIssue = maxDemandPeak >= AppConstants.mdWarningThresholdKva;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'System Alerts',
          subtitle: hasPfIssue || hasMdIssue
              ? 'Action required'
              : 'All systems normal',
        ),
        if (!hasPfIssue && !hasMdIssue)
          AppCard(
            color: AppColors.success.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'All parameters within normal limits',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasPfIssue)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              color: AppColors.danger.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Problem: Low PF Penalty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PF is ${currentPowerFactor.toStringAsFixed(3)} (below 0.95). A 5% reactive penalty applies.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Solution: Check APFC Panel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasMdIssue)
          AppCard(
            color: AppColors.warning.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warning: Near MD Breach',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Max demand at ${maxDemandPeak.toStringAsFixed(1)} kVA, approaching ${AppConstants.mdWarningThresholdKva.toInt()} kVA contract limit.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SavingOpportunityCard extends StatelessWidget {
  final SavingOpportunity opportunity;
  const _SavingOpportunityCard({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (opportunity.type) {
      SavingType.demandReduction => (
        Icons.trending_down_rounded,
        AppColors.kpiDemand,
      ),
      SavingType.powerFactorImprovement => (
        Icons.waves_rounded,
        AppColors.kpiPower,
      ),
      SavingType.loadSmoothing => (
        Icons.linear_scale_rounded,
        AppColors.kpiEnergy,
      ),
    };
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹${opportunity.monthlySavings.toStringAsFixed(0)}/month',
            style: AppTypography.mono(
              size: 24,
              weight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.description,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  opportunity.action,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
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
    Color bgColor;
    Color iconColor;
    IconData icon;
    switch (insight.severity) {
      case InsightSeverity.positive:
        bgColor = AppColors.success;
        iconColor = AppColors.success;
        icon = Icons.check_circle_rounded;
      case InsightSeverity.neutral:
        bgColor = AppColors.primary;
        iconColor = AppColors.primary;
        icon = Icons.info_rounded;
      case InsightSeverity.warning:
        bgColor = AppColors.warning;
        iconColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
      case InsightSeverity.critical:
        bgColor = AppColors.danger;
        iconColor = AppColors.danger;
        icon = Icons.error_rounded;
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.1),
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
                const SizedBox(height: 2),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rec.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Priority ${rec.priority}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rec.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rec.action,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
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
