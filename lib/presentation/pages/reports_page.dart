import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/export_service.dart';
import '../../core/utils/excel_import_service.dart';
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_table.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
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

enum _ReportPeriod {
  thisMonth('This Month'),
  lastMonth('Last Month'),
  allTime('All Time');

  const _ReportPeriod(this.label);
  final String label;
}

class _ReportsContent extends StatefulWidget {
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
  State<_ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<_ReportsContent> {
  _ReportPeriod _period = _ReportPeriod.allTime;
  String? _meter;
  String? _site;
  Map<String, double> _actualBills = {};
  Map<String, String> _meterSites = {};

  @override
  void initState() {
    super.initState();
    BillReconcileStore.load().then((bills) {
      if (mounted) setState(() => _actualBills = bills);
    });
    _loadMeterSites();
  }

  Future<void> _loadMeterSites() async {
    try {
      final meters = await context.read<MeterRepository>().getAllMeters();
      if (!mounted) return;
      setState(() {
        _meterSites = {for (final m in meters) m.name: m.site};
      });
    } catch (_) {
      // Best-effort — reports still render without site filter.
    }
  }

  List<String> get _siteNames {
    final names = _meterSites.values.toSet().toList()..sort();
    return names;
  }

  List<EnergyLogEntity> get _allEntities => widget.logs.cast<EnergyLogEntity>();

  /// Logs filtered by the selected site (Issue 7E).
  List<EnergyLogEntity> get _entities {
    if (_site == null) return _allEntities;
    final meterNames = <String>{
      for (final e in _meterSites.entries)
        if (e.value == _site) e.key,
    };
    if (meterNames.isEmpty) return const [];
    return _allEntities
        .where((e) => meterNames.contains(e.meterName))
        .toList();
  }

  List<String> get _meterNames =>
      _entities.map((e) => e.meterName).toSet().toList()..sort();

  /// Logs filtered by the selected meter + period (Issue 6).
  List<EnergyLogEntity> get _visibleLogs {
    var result = _entities;
    if (_meter != null) {
      result = result.where((e) => e.meterName == _meter).toList();
    }
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.thisMonth:
        return result
            .where(
              (e) =>
                  e.loggedAt.year == now.year && e.loggedAt.month == now.month,
            )
            .toList();
      case _ReportPeriod.lastMonth:
        final prev = DateTime(now.year, now.month - 1, 1);
        return result
            .where(
              (e) =>
                  e.loggedAt.year == prev.year && e.loggedAt.month == prev.month,
            )
            .toList();
      case _ReportPeriod.allTime:
        return result;
    }
  }

  Future<void> _pickAndImportExcel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    var sourceFile = '';
    final drafts = <ExcelReadingDraft>[];
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        sourceFile = file.name;
        drafts.addAll(await ExcelImportService.extractReadings(bytes));
      }
    } catch (e) {
      AppLogger.e('Excel import failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (drafts.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readings found in the selected Excel file(s)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ImportPreviewDialog(
        drafts: drafts,
        sourceFile: sourceFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final entityLogs = _visibleLogs;
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
                label: 'Import Data',
                icon: Icons.file_upload_outlined,
                onPressed: () => _pickAndImportExcel(context),
              ),
              const SizedBox(width: 8),
              AppButtonOutline(
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () async {
                  final entities = _visibleLogs;
                  try {
                    await PdfReportService.exportPdf(
                      logs: entities,
                      title: 'Energy Management Report',
                      subtitle:
                          '${entities.length} reading(s) — '
                          '${_period.label}${_meter != null ? ', $_meter' : ''}',
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
                },
              ),
              const SizedBox(width: 8),
              AppButtonOutline(
                label: 'Export CSV',
                icon: Icons.file_download_rounded,
                onPressed: () => ExportService().exportCsv(_visibleLogs),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey(_site),
                initialValue: _site,
                decoration: const InputDecoration(
                  labelText: 'Site',
                  isDense: true,
                  prefixIcon: Icon(Icons.factory_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Sites'),
                  ),
                  for (final site in _siteNames)
                    DropdownMenuItem<String?>(
                      value: site,
                      child: Text(site),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _site = v;
                  _meter = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey(_meter),
                initialValue: _meter,
                decoration: const InputDecoration(
                  labelText: 'Meter',
                  isDense: true,
                  prefixIcon: Icon(Icons.speed_rounded, size: 20),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Meters'),
                  ),
                  for (final name in _meterNames)
                    DropdownMenuItem<String?>(
                      value: name,
                      child: Text(name),
                    ),
                ],
                onChanged: (v) => setState(() => _meter = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<_ReportPeriod>(
                initialValue: _period,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  isDense: true,
                  prefixIcon: Icon(Icons.calendar_month, size: 20),
                ),
                items: [
                  for (final p in _ReportPeriod.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _period = v ?? _ReportPeriod.allTime),
              ),
            ),
          ],
        ),
        _buildExecutiveSummary(currencyFmt, entityLogs, breakdown, kpis),
        const SizedBox(height: AppSpacing.lg),
        _buildMonthlyHistory(),
        const SizedBox(height: AppSpacing.lg),
        _buildBillAccuracy(currencyFmt),
        const SizedBox(height: AppSpacing.lg),
        if (widget.logs.isEmpty)
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

  /// Actual vs estimated bill reconciliation (Issue 7B).
  Widget _buildBillAccuracy(NumberFormat currencyFmt) {
    final monthKeys = <String>{};
    for (final e in _entities) {
      monthKeys.add(_monthKey(e.loggedAt.year, e.loggedAt.month));
    }
    final months = monthKeys.toList()..sort((a, b) => b.compareTo(a));
    if (months.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Accuracy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Estimated vs actual utility bill per month',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButtonOutline(
                label: 'Enter Actual Bill',
                icon: Icons.edit_note_rounded,
                onPressed: () => _promptActualBill(context, months),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (months.isEmpty)
            const Text(
              'No readings yet',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final key in months) _buildBillRow(key, currencyFmt),
          if (_actualBills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearActualBills,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear all'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillRow(String key, NumberFormat currencyFmt) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final label = DateFormat('MMM yyyy').format(DateTime(year, month, 1));

    var estimated = 0.0;
    for (final e in _entities) {
      if (_monthKey(e.loggedAt.year, e.loggedAt.month) == key) {
        estimated += e.estimatedBill;
      }
    }
    final actual = _actualBills[key];

    String diffText;
    Color diffColor;
    if (actual == null) {
      diffText = 'No actual bill entered';
      diffColor = AppColors.textSecondary;
    } else {
      final diff = actual - estimated;
      final pct = estimated > 0 ? (diff / estimated).abs() * 100 : 0;
      final sign = diff > 0 ? '+' : (diff < 0 ? '-' : '±');
      diffText =
          '$sign${currencyFmt.format(diff.abs())} '
          '(${pct.toStringAsFixed(1)}%)';
      final tolerance = AppConstants.billAccuracyTolerancePercent;
      diffColor = pct <= tolerance
          ? AppColors.success
          : (diff > 0 ? AppColors.danger : AppColors.warning);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Est. ${currencyFmt.format(estimated)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              actual == null
                  ? '—'
                  : 'Actual ${currencyFmt.format(actual)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              diffText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: diffColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptActualBill(
    BuildContext context,
    List<String> months,
  ) async {
    final formKey = GlobalKey<FormState>();
    var selectedKey = months.first;
    final amountCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Actual Bill'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedKey,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  isDense: true,
                ),
                items: [
                  for (final key in months)
                    DropdownMenuItem(value: key, child: Text(key)),
                ],
                onChanged: (v) => selectedKey = v ?? selectedKey,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bill amount (₹)',
                  isDense: true,
                ),
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (value == null || value <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, amountCtrl.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final amount = double.tryParse(result);
    if (amount == null || amount <= 0) return;

    await BillReconcileStore.saveActualBill(selectedKey, amount);
    if (!mounted) return;
    setState(() => _actualBills[selectedKey] = amount);
  }

  Future<void> _clearActualBills() async {
    await BillReconcileStore.clear();
    if (!mounted) return;
    setState(() => _actualBills = {});
  }

  String _monthKey(int year, int month) => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// Last 12 months bill trend — bar chart (Issue 6).
  Widget _buildMonthlyHistory() {
    final now = DateTime.now();
    final monthDates = <DateTime>[];
    for (var i = 11; i >= 0; i--) {
      monthDates.add(DateTime(now.year, now.month - i, 1));
    }
    final monthBills = <double>[];
    for (final date in monthDates) {
      var total = 0.0;
      for (final e in _entities) {
        if (e.loggedAt.year == date.year && e.loggedAt.month == date.month) {
          total += e.estimatedBill;
        }
      }
      monthBills.add(total);
    }
    final maxBill = monthBills.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Bill History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 12 months — estimated bill (₹)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: (maxBill * 1.15).clamp(1.0, double.infinity),
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${DateFormat('MMM yy').format(monthDates[group.x])}: '
                        '₹${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthDates.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(monthDates[i]),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < monthDates.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: monthBills[i],
                          width: 12,
                          borderRadius: BorderRadius.circular(3),
                          color: monthBills[i] > 0
                              ? AppColors.primary
                              : AppColors.borderLight,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final entities = _visibleLogs;
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

/// Preview + edit screen for readings parsed from an Excel file.
/// Nothing is saved until the user confirms (Issue 11 — manual edit mandatory).
class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({required this.drafts, required this.sourceFile});

  final List<ExcelReadingDraft> drafts;
  final String sourceFile;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  List<MeterModel> _meters = [];
  bool _saving = false;

  late final List<_DraftEditor> _editors =
      widget.drafts.map((d) => _DraftEditor(d)).toList();

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  @override
  void dispose() {
    for (final e in _editors) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeters() async {
    final meters = await context.read<MeterRepository>().getAllMeters();
    if (!mounted) return;
    setState(() {
      _meters = meters;
      for (final e in _editors) {
        if (meters.isEmpty) break;
        final known = meters.any((m) => m.name == e.meterName);
        if (e.meterName.isEmpty || !known) {
          e.meterName = meters.first.name;
        }
      }
    });
  }

  MeterModel? _meterByName(String name) {
    for (final m in _meters) {
      if (m.name == name) return m;
    }
    return null;
  }

  Future<void> _pickDate(_DraftEditor editor) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: editor.loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        editor.dateCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    final models = <EnergyLogModel>[];
    for (final e in _editors) {
      if (!e.valid) continue;
      final meter = _meterByName(e.meterName);
      models.add(
        EnergyLogModel.create(
          meterName: e.meterName,
          kwh: e.kwh,
          kvah: e.kvah,
          rkvarhLag: e.lag,
          rkvarhLead: e.lead,
          mdRecorded: e.md,
          contractDemand:
              meter?.contractDemandKw ?? AppConstants.defaultContractDemandKva,
          loggedAt: e.loggedAt,
          multiplyingFactor: meter?.multiplyingFactor ?? 1.0,
        ),
      );
    }

    if (models.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koi valid reading nahi mili — kWh aur MD bharo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final count = await context
          .read<EnergyRepository>()
          .bulkSaveReadings(models);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count reading(s) imported successfully'),
          backgroundColor: Colors.green,
        ),
      );
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    } catch (e) {
      AppLogger.e('Bulk import save failed', e);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _editors.where((e) => e.valid).length;
    return AlertDialog(
      title: const Text('Import Readings'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.drafts.length} reading(s) mili — ${widget.sourceFile}. '
              'Values verify karke import karo.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _editors.length,
                itemBuilder: (context, i) => _buildDraftCard(_editors[i], i),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Import $validCount Reading(s)',
          icon: Icons.check_circle_outline,
          onPressed: _saving || validCount == 0 ? null : _import,
          loading: _saving,
        ),
      ],
    );
  }

  Widget _buildDraftCard(_DraftEditor e, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  e.draft.sourceLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!e.valid)
                  const Text(
                    'Incomplete',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('meter-$index-${e.meterName}'),
              initialValue: _meters.any((m) => m.name == e.meterName)
                  ? e.meterName
                  : null,
              hint: const Text('Select Meter'),
              decoration: const InputDecoration(
                labelText: 'Meter',
                isDense: true,
                prefixIcon: Icon(Icons.speed_rounded, size: 20),
              ),
              items: _meters
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.name,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => e.meterName = v);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: e.dateCtrl,
              label: 'Reading Date',
              prefixIcon: Icons.event,
              suffixIcon: Icons.calendar_month,
              onSuffixTap: () => _pickDate(e),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: e.kwhCtrl,
                    label: 'Units (kWh)',
                    prefixIcon: Icons.bolt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.kvahCtrl,
                    label: 'kVAh',
                    prefixIcon: Icons.electrical_services,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: e.mdCtrl,
                    label: 'MD Recorded (kVA)',
                    prefixIcon: Icons.trending_up,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.lagCtrl,
                    label: 'rkVARh Lag',
                    prefixIcon: Icons.warning_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.leadCtrl,
                    label: 'rkVARh Lead',
                    prefixIcon: Icons.check_circle_outline,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftEditor {
  _DraftEditor(this.draft)
    : meterName = draft.meterName,
      dateCtrl = TextEditingController(
        text: '${draft.loggedAt.day.toString().padLeft(2, '0')}'
            '/${draft.loggedAt.month.toString().padLeft(2, '0')}'
            '/${draft.loggedAt.year}',
      ),
      kwhCtrl = TextEditingController(text: _fmt(draft.kwh)),
      kvahCtrl = TextEditingController(text: _fmt(draft.kvah)),
      lagCtrl = TextEditingController(text: _fmt(draft.rkvarhLag)),
      leadCtrl = TextEditingController(text: _fmt(draft.rkvarhLead)),
      mdCtrl = TextEditingController(text: _fmt(draft.mdRecorded));

  final ExcelReadingDraft draft;
  String meterName = '';
  final TextEditingController dateCtrl;
  final TextEditingController kwhCtrl;
  final TextEditingController kvahCtrl;
  final TextEditingController lagCtrl;
  final TextEditingController leadCtrl;
  final TextEditingController mdCtrl;

  static String _fmt(double v) => v > 0 ? v.toStringAsFixed(2) : '';

  double get kwh => double.tryParse(kwhCtrl.text.trim()) ?? 0;
  double get kvah => double.tryParse(kvahCtrl.text.trim()) ?? 0;
  double get md => double.tryParse(mdCtrl.text.trim()) ?? 0;
  double get lag => double.tryParse(lagCtrl.text.trim()) ?? 0;
  double get lead => double.tryParse(leadCtrl.text.trim()) ?? 0;

  bool get valid => kwh > 0 && md > 0;

  DateTime get loggedAt {
    final m = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(dateCtrl.text.trim());
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  void dispose() {
    dateCtrl.dispose();
    kwhCtrl.dispose();
    kvahCtrl.dispose();
    lagCtrl.dispose();
    leadCtrl.dispose();
    mdCtrl.dispose();
  }
}
