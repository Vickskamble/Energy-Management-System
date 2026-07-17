import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/notification_service.dart';
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
      appBar: AppBar(title: const Text('Dashboard')),
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
              EnergyInitial() || EnergyLoading() => const Center(
                  child: CircularProgressIndicator(),
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
              EnergyValidationError _ => _buildErrorFallback(context, state.message),
              EnergyOperationFailure _ => _buildErrorFallback(context, state.message),
            };
          },
        ),
      ),
    );
  }

  Widget _buildErrorFallback(BuildContext ctx, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ctx.read<EnergyBloc>().add(
                    const LoadInitialDashboardData(),
                  ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
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
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final entityLogs = logs.cast<EnergyLogEntity>();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Row 1: Total Consumption + Est. Monthly Bill
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Consumption',
                  value: '${totalConsumption.toStringAsFixed(1)} Units',
                  icon: Icons.bolt,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Est. Monthly Bill',
                  value: currencyFmt.format(estimatedBill),
                  icon: Icons.account_balance_wallet,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Today's Consumption + PF
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: "Today's Consumption",
                  value: '${activeConsumptionToday.toStringAsFixed(1)} kWh',
                  icon: Icons.today,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Avg. Power Factor',
                  value: currentPowerFactor.toStringAsFixed(3),
                  icon: Icons.waves,
                  color: currentPowerFactor < AppConstants.pfPenaltyThreshold
                      ? Colors.red
                      : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Max Demand (kVA)
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Max Demand',
                  value: '${maxDemandPeak.toStringAsFixed(1)} kVA',
                  icon: Icons.trending_up,
                  color: maxDemandPeak >= AppConstants.mdWarningThresholdKva
                      ? Colors.amber.shade700
                      : Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Tariff Rate',
                  value: '₹${AppConstants.tariffPerUnit.toStringAsFixed(2)}/unit × ${AppConstants.multiplyingFactor.toInt()}',
                  icon: Icons.receipt_long,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Consumption & Demand Trend Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consumption & Demand Trend',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DashboardChart(
                    logs: entityLogs,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(Colors.blue, 'kWh'),
                      const SizedBox(width: 20),
                      _legendDot(Colors.orange, 'kVA'),
                      const SizedBox(width: 20),
                      _legendDot(Colors.red.shade400, 'Contract Demand'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Consumption Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Consumption (Daily)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MonthlyConsumptionChart(logs: entityLogs),
                  const SizedBox(height: 4),
                  Center(
                    child: _legendDot(Colors.green, 'kWh / Day'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Billing Summary Note
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Billing Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meter Reading × ${AppConstants.multiplyingFactor.toInt()} (MF) = ${totalConsumption.toStringAsFixed(1)} Units  |  '
                    'Rate: ₹${AppConstants.tariffPerUnit.toStringAsFixed(2)}/Unit  |  '
                    'Est. Bill: ${currencyFmt.format(estimatedBill)}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Problem & Solution Cards
          _buildProblemCards(),
        ],
      ),
    );
  }

  Widget _buildProblemCards() {
    final hasPfIssue = currentPowerFactor < AppConstants.pfPenaltyThreshold;
    final hasMdIssue = maxDemandPeak >= AppConstants.mdWarningThresholdKva;

    if (!hasPfIssue && !hasMdIssue) {
      return const Card(
        color: Color(0xFFE8F5E9),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All parameters within normal limits',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (hasPfIssue)
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Problem: Low PF Penalty',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PF is ${currentPowerFactor.toStringAsFixed(3)} (below 0.95). A 5% reactive penalty applies.',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Solution: Check APFC Panel',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasMdIssue) ...[
          if (hasPfIssue) const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warning: Near MD Breach',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Max demand at ${maxDemandPeak.toStringAsFixed(1)} kVA, approaching ${AppConstants.mdWarningThresholdKva.toStringAsFixed(0)} kVA contract limit.',
                          style: TextStyle(color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
