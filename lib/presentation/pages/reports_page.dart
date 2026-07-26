import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/export_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_table.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/insights/insight_generator.dart';
import '../../core/recommendations/recommendation_engine.dart';
import '../../core/validation/data_validator.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_state.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          return switch (state) {
            EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(message: 'Loading reports...'),
            EnergySuccess(
              :final logs,
              :final estimatedBill,
              :final activeConsumptionToday,
              :final currentPowerFactor,
              :final maxDemandPeak,
            ) =>
              _ReportsContent(
                logs: logs,
                estimatedBill: estimatedBill,
                activeConsumptionToday: activeConsumptionToday,
                currentPowerFactor: currentPowerFactor,
                maxDemandPeak: maxDemandPeak,
              ),
            EnergyValidationError _ => Center(child: Text(state.message)),
            EnergyOperationFailure _ => Center(child: Text(state.message)),
          };
        },
      ),
    );
  }
}

class _ReportsContent extends StatelessWidget {
  final List<dynamic> logs;
  final double estimatedBill;
  final double activeConsumptionToday;
  final double currentPowerFactor;
  final double maxDemandPeak;

  const _ReportsContent({
    required this.logs,
    required this.estimatedBill,
    required this.activeConsumptionToday,
    required this.currentPowerFactor,
    required this.maxDemandPeak,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final entityLogs = logs.cast<EnergyLogEntity>();
    final breakdown = BillCalculator.calculate(logs: entityLogs);
    final kpis = BillCalculator.calculateKpis(breakdown);
    final validation = DataValidator.validateLogs(entityLogs);
    final insights = InsightGenerator.generate(breakdown: breakdown, comparison: null, kpis: kpis, logs: entityLogs);
    final recommendations = RecommendationEngine.generate(breakdown: breakdown, comparison: null, logs: entityLogs);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Reports',
          subtitle: 'Executive summary and detailed analysis',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButtonOutline(
                label: 'Export CSV',
                icon: Icons.file_download_rounded,
                onPressed: () {
                  final state = context.read<EnergyBloc>().state;
                  if (state is EnergySuccess) {
                    final entities = state.logs.cast<EnergyLogEntity>();
                    ExportService().exportCsv(entities);
                  }
                },
              ),
            ],
          ),
        ),
        _buildExecutiveSummary(currencyFmt, entityLogs, breakdown, kpis),
        const SizedBox(height: AppSpacing.lg),
        _buildBillBreakdownReport(breakdown),
        const SizedBox(height: AppSpacing.lg),
        if (insights.isNotEmpty) ...[
          AppSectionHeader(title: 'Smart Insights'),
          ...insights.map((i) => _insightRow(i)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (recommendations.isNotEmpty) ...[
          AppSectionHeader(title: 'Recommendations'),
          ...recommendations.map((r) => _recRow(r)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (validation.issueCount > 0) ...[
          AppSectionHeader(title: 'Data Quality'),
          _validationSection(validation),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (logs.isEmpty)
          const AppEmptyState(icon: Icons.description_rounded, title: 'No readings recorded yet')
        else ...[
          AppSectionHeader(title: 'Reading History'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTable(
                  columns: const ['Date', 'Meter', 'kWh', 'PF', 'MD (kW)', 'Bill', 'Status'],
                  rows: _buildTableRows(currencyFmt),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutiveSummary(NumberFormat currencyFmt, List<EnergyLogEntity> entityLogs, BillBreakdown breakdown, BusinessKpi kpis) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Executive Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Bill Analysis for ${entityLogs.length} readings', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Divider(height: 24),
          Row(children: [
            _summaryItem('Est. Net Bill', currencyFmt.format(breakdown.netBill), AppColors.kpiCost),
            _summaryItem('Total Units', '${breakdown.totalUnits.toStringAsFixed(0)} kWh', AppColors.kpiEnergy),
            _summaryItem('Avg Unit Cost', '₹${breakdown.averageUnitCost.toStringAsFixed(2)}', AppColors.kpiCost),
            _summaryItem('Bill Health', '${kpis.billHealthScore.toStringAsFixed(0)}/100', kpis.billHealthScore >= 80 ? AppColors.success : AppColors.warning),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _summaryItem('Power Factor', breakdown.powerFactor.toStringAsFixed(3), AppColors.kpiPower),
            _summaryItem('Billing Demand', '${breakdown.billingDemand.toStringAsFixed(1)} kVA', AppColors.kpiDemand),
            _summaryItem('Load Factor', '${(breakdown.loadFactor * 100).toStringAsFixed(0)}%', breakdown.loadFactor >= 0.75 ? AppColors.success : AppColors.warning),
            _summaryItem('Energy Score', '${kpis.energyScore.toStringAsFixed(0)}/100', AppColors.kpiEfficiency),
          ]),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildBillBreakdownReport(BillBreakdown breakdown) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bill Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _billRow('Energy Charges', breakdown.energyCharges, breakdown.energyChargesPercent, AppColors.kpiEnergy),
          const Divider(height: 16),
          _billRow('Demand Charges', breakdown.demandCharges, breakdown.demandChargesPercent, AppColors.kpiDemand),
          const Divider(height: 16),
          _billRow('FAC', breakdown.facCharges, breakdown.facPercent, AppColors.warning),
          const Divider(height: 16),
          _billRow('Wheeling', breakdown.wheelingCharges, breakdown.wheelingPercent, AppColors.textSecondary),
          const Divider(height: 16),
          _billRow('Electricity Duty', breakdown.electricityDuty, breakdown.dutyPercent, AppColors.kpiEfficiency),
          const Divider(height: 16),
          _billRow('Taxes', breakdown.taxes, breakdown.taxesPercent, AppColors.kpiCO2),
          if (breakdown.pfRebate > 0) ...[const Divider(height: 16), _rebateRow('PF Rebate', breakdown.pfRebate)],
          if (breakdown.pfSurcharge > 0) ...[const Divider(height: 16), _penaltyRow('PF Surcharge', breakdown.pfSurcharge)],
          const Divider(height: 16),
          _billRow('Net Bill', breakdown.netBill, 100, AppColors.primary, bold: true),
        ],
      ),
    );
  }

  Widget _billRow(String label, double amount, double percent, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          if (percent > 0 && percent < 100) Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _rebateRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('-₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
        ],
      ),
    );
  }

  Widget _penaltyRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('+₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
        ],
      ),
    );
  }

  Widget _insightRow(InsightItem insight) {
    final iconColor = switch (insight.severity) {
      InsightSeverity.positive => AppColors.success,
      InsightSeverity.neutral => AppColors.primary,
      InsightSeverity.warning => AppColors.warning,
      InsightSeverity.critical => AppColors.danger,
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(insight.description, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _recRow(RecommendationItem rec) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(rec.action, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (rec.estimatedSavings != null)
                Text('Savings: ₹${rec.estimatedSavings!.toStringAsFixed(0)}/mo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _validationSection(ValidationResult validation) {
    return AppCard(
      child: Column(
        children: [
          ...validation.passed.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: 8), Text(p, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
          )),
          ...validation.warnings.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning), const SizedBox(width: 8), Expanded(child: Text(w, style: TextStyle(fontSize: 12, color: AppColors.warning)))]),
          )),
          ...validation.errors.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [Icon(Icons.error, size: 14, color: AppColors.danger), const SizedBox(width: 8), Expanded(child: Text(e, style: TextStyle(fontSize: 12, color: AppColors.danger)))]),
          )),
        ],
      ),
    );
  }

  List<List<Widget>> _buildTableRows(NumberFormat currencyFmt) {
    final entities = logs.cast<EnergyLogEntity>();
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    return entities.map((log) => [
      Text(dateFmt.format(log.loggedAt)),
      Text(log.meterName),
      Text(log.kwh.toStringAsFixed(1)),
      Text(log.powerFactor.toStringAsFixed(3)),
      Text(log.mdRecorded.toStringAsFixed(1)),
      Text('₹ ${log.estimatedBill.toStringAsFixed(0)}'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (log.isSynced ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(log.isSynced ? 'Cloud' : 'Pending',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: log.isSynced ? AppColors.success : AppColors.warning)),
      ),
    ]).toList();
  }
}
