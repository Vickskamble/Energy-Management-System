import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
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

class _AnalysisContent extends StatefulWidget {
  final List<dynamic> logs;
  const _AnalysisContent({required this.logs});

  @override
  State<_AnalysisContent> createState() => _AnalysisContentState();
}

class _AnalysisContentState extends State<_AnalysisContent> {
  static const int _pageSize = 25;
  late int _visibleCount;
  String? _selectedMeter;

  @override
  void initState() {
    super.initState();
    _visibleCount = _pageSize;
  }

  @override
  void didUpdateWidget(covariant _AnalysisContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs.length != widget.logs.length) {
      _visibleCount = _pageSize;
    }
  }

  List<EnergyLogEntity> get _entities => widget.logs.cast<EnergyLogEntity>();

  List<String> get _meterNames {
    final names = _entities.map((e) => e.meterName).toSet().toList()..sort();
    return names;
  }

  List<EnergyLogEntity> get _filtered {
    final all = _entities;
    if (_selectedMeter == null) return all;
    return all.where((e) => e.meterName == _selectedMeter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_entities.isEmpty) {
      return const AppEmptyState(
        icon: Icons.analytics_rounded,
        title: 'No readings recorded yet',
        subtitle: 'Add readings to see analysis',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (_meterNames.isNotEmpty) ...[
            _buildMeterSelector(),
            const SizedBox(height: 12),
            _buildMeterTrends(),
            const SizedBox(height: 24),
          ],
          AppSectionHeader(
            title: 'Reading History',
            subtitle:
                '${_filtered.length} reading(s) — tap edit or delete to correct data',
          ),
          const SizedBox(height: 8),
          _buildLogList(_filtered),
          if (_visibleCount < _filtered.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Load More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Meter selector chips ──────────────────────────────────────────────
  Widget _buildMeterSelector() {
    final names = _meterNames;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _meterChip('All Meters', null),
          for (final name in names) _meterChip(name, name),
        ],
      ),
    );
  }

  Widget _meterChip(String label, String? value) {
    final selected = _selectedMeter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedMeter = value),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ── Per-meter trend charts ────────────────────────────────────────────
  Widget _buildMeterTrends() {
    final target = _selectedMeter;
    final meterLogs =
        _entities.where((e) => target == null || e.meterName == target).toList()
          ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    if (meterLogs.length < 2) {
      return const SizedBox.shrink();
    }

    final recent = meterLogs.length > 30
        ? meterLogs.sublist(meterLogs.length - 30)
        : meterLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Trends',
          subtitle:
              'Last ${recent.length} readings — ${target ?? 'all meters'}',
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppCard(
                child: _miniLineChart(
                  title: 'kWh Consumption',
                  color: AppColors.primary,
                  values: recent.map((e) => e.kwh).toList(),
                  unit: 'kWh',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                child: _miniLineChart(
                  title: 'Max Demand (kVA)',
                  color: AppColors.warning,
                  values: recent.map((e) => e.mdRecorded).toList(),
                  unit: 'kVA',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniLineChart({
    required String title,
    required Color color,
    required List<double> values,
    required String unit,
  }) {
    final spots = <FlSpot>[
      for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (values.length - 1).toDouble(),
              minY: 0,
              maxY: maxY.clamp(1.0, double.infinity),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 3).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: AppColors.borderLight, strokeWidth: 1),
              ),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.08),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map(
                        (spot) => LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} $unit',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Reading list with edit/delete ─────────────────────────────────────
  Widget _buildLogList(List<EnergyLogEntity> entities) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final visible = entities.take(_visibleCount).toList();

    return Column(
      children: visible
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
                        IconButton(
                          tooltip: 'Edit reading',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showEditDialog(log),
                        ),
                        IconButton(
                          tooltip: 'Delete reading',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _confirmDelete(log),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        _dataCell(
                          'kWh',
                          log.kwh.toStringAsFixed(1),
                          AppColors.kpiEnergy,
                        ),
                        _dataCell(
                          'Unit Cost',
                          log.kwh > 0
                              ? '₹${(log.estimatedBill / log.kwh).toStringAsFixed(2)}'
                              : '—',
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

  Future<void> _showEditDialog(EnergyLogEntity log) async {
    final kwhCtrl = TextEditingController(text: log.kwh.toStringAsFixed(2));
    final kvahCtrl = TextEditingController(text: log.kvah.toStringAsFixed(2));
    final mdCtrl = TextEditingController(
      text: log.mdRecorded.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          var date = log.loggedAt;
          return AlertDialog(
            title: const Text('Edit Reading'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: kwhCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consumed kWh',
                        prefixIcon: Icon(Icons.bolt_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) {
                          return 'Enter a positive value';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: kvahCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consumed kVAh',
                        prefixIcon: Icon(Icons.speed_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) {
                          return 'Enter a positive value';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'MD Recorded (kVA)',
                        prefixIcon: Icon(Icons.trending_up),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) {
                          return 'Enter a positive value';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined, size: 20),
                      title: Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(date),
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(
                        Icons.edit_calendar_outlined,
                        size: 18,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked == null) return;
                        if (!dialogCtx.mounted) return;
                        final time = await showTimePicker(
                          context: dialogCtx,
                          initialTime: TimeOfDay.fromDateTime(date),
                        );
                        if (time == null) return;
                        setDialogState(() {
                          date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final updatedModel = EnergyLogModel.create(
                    id: log.id,
                    meterName: log.meterName,
                    kwh: double.parse(kwhCtrl.text.trim()),
                    kvah: double.parse(kvahCtrl.text.trim()),
                    mdRecorded: double.parse(mdCtrl.text.trim()),
                    loggedAt: date,
                    contractDemand: log.contractDemand,
                    userId: log.userId,
                  );
                  Navigator.pop(dialogCtx);
                  try {
                    await context.read<EnergyRepository>().updateReading(
                      updatedModel,
                    );
                    if (mounted) {
                      context.read<EnergyBloc>().add(
                        const LoadInitialDashboardData(),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reading updated'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    AppLogger.e('Update failed', e);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Update failed: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(EnergyLogEntity log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Reading'),
        content: Text(
          'Delete the reading for ${log.meterName} at '
          '${DateFormat('dd MMM yyyy, HH:mm').format(log.loggedAt)}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<EnergyRepository>().deleteReading(
        log.id,
        synced: log.isSynced,
      );
      if (mounted) {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      }
    } catch (e) {
      AppLogger.e('Delete failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
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
