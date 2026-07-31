import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
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

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppSectionHeader(
            title: 'Reading History',
            subtitle:
                '${entities.length} reading(s) — har reading ka detailed record',
          ),
          _buildLogList(entities),
        ],
      ),
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
                          'Unit Cost',
                          '₹${(log.estimatedBill / log.kwh).toStringAsFixed(2)}',
                          AppColors.kpiCost,
                        ),
                        _dataCell(
                          'PF',
                          log.powerFactor.toStringAsFixed(3),
                          AppColors.kpiPower,
                        ),
                        _dataCell(
                          'MD (kVA)',
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
