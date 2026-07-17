import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/utils/export_service.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_state.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () {
              context.read<EnergyBloc>().state;
              final state = context.read<EnergyBloc>().state;
              if (state is EnergySuccess) {
                final entities = state.logs.cast<EnergyLogEntity>();
                ExportService().exportCsv(entities);
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          return switch (state) {
            EnergyInitial() || EnergyLoading() => const Center(
                child: CircularProgressIndicator(),
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

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _summaryChip('Est. Bill', currencyFmt.format(estimatedBill)),
              _summaryChip('Today', '${activeConsumptionToday.toStringAsFixed(1)} kWh'),
              _summaryChip('PF', currentPowerFactor.toStringAsFixed(3)),
              _summaryChip('Peak MD', '${maxDemandPeak.toStringAsFixed(1)} kW'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('No readings recorded yet'))
              : _LogCardList(logs: logs.cast<EnergyLogEntity>()),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _LogCardList extends StatelessWidget {
  final List<EnergyLogEntity> logs;

  const _LogCardList({required this.logs});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      log.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      size: 20,
                      color: log.isSynced ? Colors.green : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.meterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.isSynced
                            ? Colors.green.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        log.isSynced ? 'Cloud' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: log.isSynced ? Colors.green.shade700 : Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateFmt.format(log.loggedAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    _dataCell('kWh', log.kwh.toStringAsFixed(1)),
                    _dataCell('PF', log.powerFactor.toStringAsFixed(3)),
                    _dataCell('MD (kW)', log.mdRecorded.toStringAsFixed(1)),
                    _dataCell('Bill', '₹ ${log.estimatedBill.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dataCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
