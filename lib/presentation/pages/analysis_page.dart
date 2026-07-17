import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          return switch (state) {
            EnergyInitial() || EnergyLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            EnergySuccess(:final logs) => _LogListView(logs: logs),
            EnergyValidationError _ => Center(child: Text(state.message)),
            EnergyOperationFailure _ => Center(child: Text(state.message)),
          };
        },
      ),
    );
  }
}

class _LogListView extends StatelessWidget {
  final List<dynamic> logs;

  const _LogListView({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No readings recorded yet'));
    }

    final entities = logs.cast<EnergyLogEntity>();
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final numberFmt = NumberFormat.decimalPattern();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entities.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = entities[index];
          return ListTile(
            dense: true,
            title: Text(
              log.meterName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(dateFmt.format(log.loggedAt)),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${log.kwh.toStringAsFixed(1)} kWh / PF ${log.powerFactor.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '₹ ${numberFmt.format(log.estimatedBill.round())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
