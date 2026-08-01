import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/export_service.dart';
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_table.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_state.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnergyBloc, EnergyState>(
      builder: (context, state) {
        return switch (state) {
          EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(
            message: 'Loading reports...',
          ),
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
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () async {
                  final state = context.read<EnergyBloc>().state;
                  if (state is EnergySuccess) {
                    final entities = state.logs.cast<EnergyLogEntity>();
                    try {
                      await PdfReportService.exportPdf(
                        logs: entities,
                        title: 'Energy Management Report',
                        subtitle:
                            '${entities.length} reading(s) across '
                            '${entities.map((e) => e.meterName).toSet().length} meter(s)',
                      );
                    } catch (e) {
                      AppLogger.e('PDF export failed', e);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('PDF export failed: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
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
        if (logs.isEmpty)
          const AppEmptyState(
            icon: Icons.description_rounded,
            title: 'No readings recorded yet',
          )
        else ...[
          AppSectionHeader(title: 'Reading History'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTable(
                  columns: const [
                    'Date',
                    'Meter',
                    'kWh',
                    'Unit Cost',
                    'PF',
                    'MD (kVA)',
                    'Bill',
                    'Status',
                  ],
                  rows: _buildTableRows(currencyFmt),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutiveSummary(
    NumberFormat currencyFmt,
    List<EnergyLogEntity> entityLogs,
    BillBreakdown breakdown,
    BusinessKpi kpis,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Executive Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Bill Analysis for ${entityLogs.length} readings',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 24),
          Row(
            children: [
              _summaryItem(
                'Est. Net Bill',
                currencyFmt.format(breakdown.netBill),
                AppColors.kpiCost,
              ),
              _summaryItem(
                'Total Units',
                '${breakdown.totalUnits.toStringAsFixed(0)} kWh',
                AppColors.kpiEnergy,
              ),
              _summaryItem(
                'Avg Unit Cost',
                '₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
                AppColors.kpiCost,
              ),
              _summaryItem(
                'Bill Health',
                '${kpis.billHealthScore.toStringAsFixed(0)}/100',
                kpis.billHealthScore >= 80
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem(
                'Power Factor',
                breakdown.powerFactor.toStringAsFixed(3),
                AppColors.kpiPower,
              ),
              _summaryItem(
                'Billing Demand',
                '${breakdown.billingDemand.toStringAsFixed(1)} kVA',
                AppColors.kpiDemand,
              ),
              _summaryItem(
                'Load Factor',
                '${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
                breakdown.loadFactor >= 0.75
                    ? AppColors.success
                    : AppColors.warning,
              ),
              _summaryItem(
                'Energy Score',
                '${kpis.energyScore.toStringAsFixed(0)}/100',
                AppColors.kpiEfficiency,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
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

  List<List<Widget>> _buildTableRows(NumberFormat currencyFmt) {
    final entities = logs.cast<EnergyLogEntity>();
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    return entities
        .map(
          (log) => [
            Text(dateFmt.format(log.loggedAt)),
            Text(log.meterName),
            Text(log.kwh.toStringAsFixed(1)),
            Text(
              log.kwh > 0
                  ? '₹${(log.estimatedBill / log.kwh).toStringAsFixed(2)}'
                  : '—',
            ),
            Text(log.powerFactor.toStringAsFixed(3)),
            Text(log.mdRecorded.toStringAsFixed(1)),
            Text('₹ ${log.estimatedBill.toStringAsFixed(0)}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (log.isSynced ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.isSynced ? 'Cloud' : 'Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: log.isSynced ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ],
        )
        .toList();
  }
}
