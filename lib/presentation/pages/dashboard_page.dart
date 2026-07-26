import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_kpi_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/validation/data_validator.dart';
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
    return Scaffold(
      body: BlocListener<EnergyBloc, EnergyState>(
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
              EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(message: 'Loading dashboard...'),
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
              EnergyValidationError _ => AppErrorState(message: state.message, onRetry: () => context.read<EnergyBloc>().add(const LoadInitialDashboardData())),
              EnergyOperationFailure _ => AppErrorState(message: state.message, onRetry: () => context.read<EnergyBloc>().add(const LoadInitialDashboardData())),
            };
          },
        ),
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
    final validation = DataValidator.validateLogs(entityLogs);
    final insights = InsightGenerator.generate(breakdown: breakdown, comparison: null, kpis: kpis, logs: entityLogs);
    final recommendations = RecommendationEngine.generate(breakdown: breakdown, comparison: null, logs: entityLogs);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppSectionHeader(title: 'Energy Overview', subtitle: 'Bill analysis and monitoring dashboard'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              AppKpiCard(
                title: 'Bill Health Score',
                value: kpis.billHealthScore,
                suffix: '/100',
                icon: Icons.health_and_safety_rounded,
                color: kpis.billHealthScore >= 80 ? AppColors.kpiEfficiency : (kpis.billHealthScore >= 60 ? AppColors.warning : AppColors.danger),
                decimals: 0,
                description: kpis.billHealthScore >= 80 ? 'Good — all parameters optimized' : kpis.billHealthScore >= 60 ? 'Needs attention' : 'Critical issues',
              ),
              AppKpiCard(
                title: 'Est. Monthly Bill',
                value: estimatedBill,
                suffix: '₹',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.kpiCost,
                decimals: 0,
                description: 'Avg unit cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
              ),
              AppKpiCard(
                title: 'Energy Charges',
                value: breakdown.energyChargesPercent,
                suffix: '% of bill',
                icon: Icons.bolt_rounded,
                color: AppColors.kpiEnergy,
                decimals: 1,
                description: breakdown.energyChargesPercent > 60 ? 'Dominant — focus on efficiency' : 'Well distributed',
              ),
              AppKpiCard(
                title: 'Power Factor',
                value: currentPowerFactor,
                suffix: 'PF',
                icon: Icons.waves_rounded,
                color: currentPowerFactor < AppConstants.pfPenaltyThreshold ? AppColors.danger : AppColors.kpiPower,
                trendValue: -0.5,
                trendUp: false,
                decimals: 3,
                description: currentPowerFactor >= AppConstants.pfRebateThreshold ? 'Rebate earned' : (currentPowerFactor >= AppConstants.pfSurchargeThreshold ? 'Near rebate' : 'Penalty applies'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              AppKpiCard(
                title: 'Total Consumption',
                value: totalConsumption,
                suffix: 'kWh',
                icon: Icons.bolt_rounded,
                color: AppColors.kpiEnergy,
                decimals: 0,
                description: '${breakdown.totalUnits.toStringAsFixed(0)} billed units',
              ),
              AppKpiCard(
                title: 'Max Demand',
                value: maxDemandPeak,
                suffix: 'kVA',
                icon: Icons.trending_up_rounded,
                color: maxDemandPeak >= AppConstants.mdWarningThresholdKva ? AppColors.warning : AppColors.kpiDemand,
                description: 'Billing demand: ${breakdown.billingDemand.toStringAsFixed(1)} kVA',
              ),
              AppKpiCard(
                title: 'Load Factor',
                value: breakdown.loadFactor * 100,
                suffix: '%',
                icon: Icons.speed_rounded,
                color: breakdown.loadFactor >= AppConstants.loadFactorThresholdGood ? AppColors.kpiEfficiency : AppColors.warning,
                decimals: 0,
                description: breakdown.loadFactor >= AppConstants.loadFactorThresholdGood ? 'Efficient usage' : 'Improve load smoothing',
              ),
              AppKpiCard(
                title: "Today's Usage",
                value: activeConsumptionToday,
                suffix: 'kWh',
                icon: Icons.today_rounded,
                color: AppColors.kpiSavings,
                trendValue: -6.1,
                trendUp: false,
                trendLabel: 'vs yesterday',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          if (breakdown.netBill > 0) _buildBillBreakdown(context, breakdown),
          if (breakdown.netBill > 0) const SizedBox(height: AppSpacing.xl),

          if (insights.isNotEmpty) ...[
            AppSectionHeader(title: 'Smart Insights', subtitle: 'What these numbers mean for your business'),
            ...insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InsightCard(insight: i),
            )),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (recommendations.isNotEmpty) ...[
            AppSectionHeader(title: 'Recommendations', subtitle: 'Actionable steps to reduce your bill'),
            ...recommendations.take(3).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecommendationCard(rec: r),
            )),
            const SizedBox(height: AppSpacing.xl),
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
                      const Text('Consumption & Demand Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      const Text('Monthly Consumption', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

          DataValidatorSection(validation: validation),
          const SizedBox(height: AppSpacing.lg),

          _buildAlertsSection(context),
        ],
      ),
    );
  }

  Widget _buildBillBreakdown(BuildContext context, BillBreakdown breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Bill Breakdown', subtitle: '₹${breakdown.netBill.toStringAsFixed(0)} total estimated bill'),
        AppCard(
          child: Column(
            children: [
              _billRow('Energy Charges', breakdown.energyCharges, breakdown.energyChargesPercent, AppColors.kpiEnergy),
              const Divider(height: 24),
              _billRow('Demand Charges', breakdown.demandCharges, breakdown.demandChargesPercent, AppColors.kpiDemand),
              const Divider(height: 24),
              _billRow('FAC', breakdown.facCharges, breakdown.facPercent, AppColors.warning),
              const Divider(height: 24),
              _billRow('Wheeling Charges', breakdown.wheelingCharges, breakdown.wheelingPercent, AppColors.textSecondary),
              const Divider(height: 24),
              _billRow('Electricity Duty', breakdown.electricityDuty, breakdown.dutyPercent, AppColors.kpiEfficiency),
              const Divider(height: 24),
              _billRow('Taxes', breakdown.taxes, breakdown.taxesPercent, AppColors.kpiCO2),
              if (breakdown.pfRebate > 0) ...[const Divider(height: 24), _billRow('PF Rebate', -breakdown.pfRebate, 0, AppColors.success)],
              if (breakdown.pfSurcharge > 0) ...[const Divider(height: 24), _billRow('PF Surcharge', breakdown.pfSurcharge, 0, AppColors.danger)],
              if (breakdown.subsidy > 0) ...[const Divider(height: 24), _billRow('Subsidy', -breakdown.subsidy, 0, AppColors.success)],
              const Divider(height: 24),
              _billRow('Net Bill', breakdown.netBill, 100, AppColors.primary, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _billRow(String label, double amount, double percent, Color color, {bool bold = false}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        if (percent > 0) Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        Text('₹${amount.abs().toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: amount >= 0 ? null : AppColors.success)),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final hasPfIssue = currentPowerFactor < AppConstants.pfPenaltyThreshold;
    final hasMdIssue = maxDemandPeak >= AppConstants.mdWarningThresholdKva;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'System Alerts', subtitle: hasPfIssue || hasMdIssue ? 'Action required' : 'All systems normal'),
        if (!hasPfIssue && !hasMdIssue)
          AppCard(
            color: AppColors.success.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Text('All parameters within normal limits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.success))),
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
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Problem: Low PF Penalty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        const SizedBox(height: 2),
                        Text('PF is ${currentPowerFactor.toStringAsFixed(3)} (below 0.95). A 5% reactive penalty applies.', style: TextStyle(fontSize: 12, color: AppColors.danger.withValues(alpha: 0.8))),
                        const SizedBox(height: 2),
                        const Text('Solution: Check APFC Panel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
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
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.trending_up_rounded, color: AppColors.warning, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Warning: Near MD Breach', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.warning)),
                      const SizedBox(height: 2),
                      Text('Max demand at ${maxDemandPeak.toStringAsFixed(1)} kVA, approaching ${AppConstants.mdWarningThresholdKva.toInt()} kVA contract limit.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning.withValues(alpha: 0.8))),
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
            width: 36, height: 36,
            decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(insight.description, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (insight.recommendation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(insight.recommendation!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warning)),
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
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Priority ${rec.priority}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(rec.description, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(rec.action, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary))),
                  ],
                ),
                if (rec.estimatedSavings != null && rec.estimatedSavings! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.savings_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Potential savings: ₹${rec.estimatedSavings!.toStringAsFixed(0)}/month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
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

class DataValidatorSection extends StatelessWidget {
  final ValidationResult validation;
  const DataValidatorSection({super.key, required this.validation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Data Validation', subtitle: validation.summary),
        AppCard(
          child: Column(
            children: [
              if (validation.passed.isNotEmpty) ...[
                ...validation.passed.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(p, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )),
              ],
              if (validation.warnings.isNotEmpty) ...[
                if (validation.passed.isNotEmpty) const SizedBox(height: 8),
                ...validation.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w, style: TextStyle(fontSize: 12, color: AppColors.warning))),
                    ],
                  ),
                )),
              ],
              if (validation.errors.isNotEmpty) ...[
                if (validation.passed.isNotEmpty || validation.warnings.isNotEmpty) const SizedBox(height: 8),
                ...validation.errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.error, size: 14, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e, style: TextStyle(fontSize: 12, color: AppColors.danger))),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
