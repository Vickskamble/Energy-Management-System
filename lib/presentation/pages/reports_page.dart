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
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_table.dart';
import '../../core/widgets/month_filter_bar.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../data/repositories/meter_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';

class ReportsPage extends StatelessWidget {
  final MonthFilterController monthFilter;

  const ReportsPage({super.key, required this.monthFilter});

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
              monthFilter: monthFilter,
            ),
          EnergyValidationError _ => AppErrorState(
            message: state.message,
            onRetry: () => context
                .read<EnergyBloc>()
                .add(const LoadInitialDashboardData()),
          ),
          EnergyOperationFailure _ => AppErrorState(
            message: state.message,
            onRetry: () => context
                .read<EnergyBloc>()
                .add(const LoadInitialDashboardData()),
          ),
        };
      },
    );
  }
}

class _ReportsContent extends StatefulWidget {
  final List<dynamic> logs;
  final double estimatedBill;
  final double activeConsumptionToday;
  final double currentPowerFactor;
  final double maxDemandPeak;
  final MonthFilterController monthFilter;

  const _ReportsContent({
    required this.logs,
    required this.estimatedBill,
    required this.activeConsumptionToday,
    required this.currentPowerFactor,
    required this.maxDemandPeak,
    required this.monthFilter,
  });

  @override
  State<_ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<_ReportsContent> {
  String? _meter;
  String? _site;
  Map<String, double> _actualBills = {};
  Map<String, String> _meterSites = {};

  MonthFilterValue get _selection => widget.monthFilter.value;

  @override
  void initState() {
    super.initState();
    BillReconcileStore.load().then((bills) {
      if (mounted) setState(() => _actualBills = bills);
    });
    _loadMeterSites();
    context.read<MeterRepository>().addListener(_loadMeterSites);
    widget.monthFilter.addListener(_onFilterChanged);
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

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_loadMeterSites);
    widget.monthFilter.removeListener(_onFilterChanged);
    super.dispose();
  }

  /// Distinct months present in the data — drives the shared filter bar.
  List<DateTime> get _monthKeys {
    final keys = <String, DateTime>{};
    for (final e in _allEntities) {
      keys['${e.loggedAt.year}-${e.loggedAt.month}'] = DateTime(
        e.loggedAt.year,
        e.loggedAt.month,
      );
    }
    final list = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
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

  /// Meters for the dropdown: every meter registered for the selected site
  /// (even without readings) plus any meter still present in log data — so
  /// added meters always appear in the selector.
  List<String> get _meterNames {
    final names = <String>{
      for (final e in _meterSites.entries)
        if (_site == null || e.value == _site) e.key,
      for (final e in _entities) e.meterName,
    }.toList()..sort();
    return names;
  }

  /// Logs filtered by the selected meter + month (Issue 6).
  List<EnergyLogEntity> get _visibleLogs {
    var result = _entities;
    if (_meter != null) {
      result = result.where((e) => e.meterName == _meter).toList();
    }
    return result.where((e) => _selection.matches(e.loggedAt)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final entityLogs = _visibleLogs;
    final breakdown = BillCalculator.calculate(
      logs: entityLogs,
      ratchetLogs: _allEntities,
    );
    final kpis = BillCalculator.calculateKpis(breakdown);

    final isNarrow = MediaQuery.of(context).size.width < 600;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Reports',
          subtitle: 'Executive summary and detailed analysis',
          trailing: isNarrow
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                '${_selection.label}${_meter != null ? ', $_meter' : ''}',
                          );
                        } catch (e) {
                          AppLogger.e('PDF export failed', e);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Could not generate the PDF report. Please try again.',
                                ),
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
        if (isNarrow) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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
                            '${_selection.label}${_meter != null ? ', $_meter' : ''}',
                      );
                    } catch (e) {
                      AppLogger.e('PDF export failed', e);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Could not generate the PDF report. Please try again.',
                            ),
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
        ],
        const SizedBox(height: 12),
        if (isNarrow)
          Column(
            children: [
              DropdownButtonFormField<String?>(
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
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
              const SizedBox(height: 12),
              MonthFilterDropdown(
                controller: widget.monthFilter,
                availableMonths: _monthKeys,
                includeAllTime: true,
              ),
            ],
          )
        else
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
                child: MonthFilterDropdown(
                  controller: widget.monthFilter,
                  availableMonths: _monthKeys,
                  includeAllTime: true,
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
                    'Reading kWh',
                    'Consumed kWh',
                    'Reading kVAh',
                    'Consumed kVAh',
                    'PF',
                    'MD (kVA)',
                    'Bill',
                    'Status',
                  ],
                  rows: _buildTableRows(currencyFmt),
                  columnWidth: 92,
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
              Expanded(
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
                        color: AppColors.dim(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.of(context).size.width >= 600)
                AppButtonOutline(
                  label: 'Enter Actual Bill',
                  icon: Icons.edit_note_rounded,
                  onPressed: () => _promptActualBill(context, months),
                ),
            ],
          ),
          if (MediaQuery.of(context).size.width < 600) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButtonOutline(
                label: 'Enter Actual Bill',
                icon: Icons.edit_note_rounded,
                onPressed: () => _promptActualBill(context, months),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (months.isEmpty)
            Text(
              'No readings yet',
              style: TextStyle(color: AppColors.dim(context)),
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

    final monthLogs = _entities
        .where((e) => _monthKey(e.loggedAt.year, e.loggedAt.month) == key)
        .toList();
    var estimated = monthLogs.fold(0.0, (s, e) => s + e.estimatedBill);
    if (monthLogs.isNotEmpty) {
      final monthBreakdown = BillCalculator.calculate(
        logs: monthLogs,
        ratchetLogs: _allEntities,
        facRate: AppConfig.facRateForMonth(key),
      );
      estimated = monthBreakdown.netBill;
    }
    final actual = _actualBills[key];

    String diffText;
    Color diffColor;
    if (actual == null) {
      diffText = 'No actual bill entered';
      diffColor = AppColors.dim(context);
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Est. ${currencyFmt.format(estimated)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dim(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        actual == null
                            ? '—'
                            : 'Actual ${currencyFmt.format(actual)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dim(context),
                        ),
                      ),
                    ),
                    Text(
                      diffText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: diffColor,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dim(context),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  actual == null
                      ? '—'
                      : 'Actual ${currencyFmt.format(actual)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dim(context),
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
          );
        },
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
    final facCtrl = TextEditingController();
    final result = await showDialog<({String amount, String? fac})>(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: facCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'FAC rate (₹/unit) — optional',
                  hintText: AppConfig.facRateForMonth(selectedKey)
                      .toStringAsFixed(2),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final value = double.tryParse(v.trim());
                  if (value == null || value < 0) {
                    return 'Invalid FAC rate';
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
                Navigator.pop(
                  dialogContext,
                  (amount: amountCtrl.text, fac: facCtrl.text.trim()),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final amount = double.tryParse(result.amount);
    if (amount == null || amount <= 0) return;

    await BillReconcileStore.saveActualBill(selectedKey, amount);
    final fac = result.fac;
    if (fac != null && fac.isNotEmpty) {
      await TariffStore.saveFacRate(selectedKey, double.tryParse(fac));
    }
    if (!mounted) return;
    setState(() {
      _actualBills[selectedKey] = amount;
    });
  }

  Future<void> _clearActualBills() async {
    await BillReconcileStore.clear();
    if (!mounted) return;
    setState(() => _actualBills = {});
  }

  String _monthKey(int year, int month) => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// Compact ₹ label for bar tops: ₹950, ₹1.2k, ₹3.4L, ₹1.1Cr.
  String _compactInr(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  /// Last 12 months bill trend — bar chart (Issue 6). Scope follows the
  /// meter dropdown (site scope stays), and each bar is a real monthly
  /// breakdown (FAC-rate aware) so the top label matches the Bill Accuracy
  /// rows instead of a sum of per-reading estimates.
  Widget _buildMonthlyHistory() {
    final now = DateTime.now();
    final scope = _meter == null
        ? _entities
        : _entities.where((e) => e.meterName == _meter).toList();
    final monthDates = <DateTime>[];
    for (var i = 11; i >= 0; i--) {
      monthDates.add(DateTime(now.year, now.month - i, 1));
    }
    final monthBills = <double>[];
    for (final date in monthDates) {
      final monthLogs = scope
          .where(
            (e) => e.loggedAt.year == date.year && e.loggedAt.month == date.month,
          )
          .toList();
      var bill = 0.0;
      if (monthLogs.isNotEmpty) {
        bill = BillCalculator.calculate(
          logs: monthLogs,
          ratchetLogs: _allEntities,
          facRate: AppConfig.facRateForMonth(_monthKey(date.year, date.month)),
        ).netBill;
      }
      monthBills.add(bill);
    }
    final maxBill = monthBills.fold(0.0, (a, b) => a > b ? a : b);

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
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
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
                          color: AppColors.textOnDark,
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
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthBills.length) {
                          return const SizedBox.shrink();
                        }
                        if (monthBills[i] <= 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _compactInr(monthBills[i]),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
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
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.dim(context),
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
                              : AppColors.line(context),
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
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const Divider(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 2 : 4;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Est. Net Bill',
                      currencyFmt.format(breakdown.netBill),
                      AppColors.kpiCost,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Total Units',
                      '${breakdown.totalUnits.toStringAsFixed(0)} kWh',
                      AppColors.kpiEnergy,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Avg Unit Cost',
                      '₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
                      AppColors.kpiCost,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Bill Health',
                      '${kpis.billHealthScore.toStringAsFixed(0)}/100',
                      kpis.billHealthScore >= 80
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 2 : 4;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Power Factor',
                      breakdown.powerFactor.toStringAsFixed(3),
                      AppColors.kpiPower,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Billing Demand',
                      '${breakdown.billingDemand.toStringAsFixed(1)} kVA',
                      AppColors.kpiDemand,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Load Factor',
                      '${(breakdown.loadFactor * 100).toStringAsFixed(0)}%',
                      breakdown.loadFactor >= 0.75
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryItem(
                      'Energy Score',
                      '${kpis.energyScore.toStringAsFixed(0)}/100',
                      AppColors.kpiEfficiency,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.dim(context)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.statusText(color, dark),
          ),
        ),
      ],
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
            Text(
              log.currentKwh != null
                  ? log.currentKwh!.toStringAsFixed(1)
                  : '—',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(log.kwh.toStringAsFixed(1)),
            Text(
              log.currentKvah != null
                  ? log.currentKvah!.toStringAsFixed(1)
                  : '—',
            ),
            Text(log.kvah.toStringAsFixed(1)),
            Text(log.powerFactor.toStringAsFixed(3)),
            Text(
              (log.mdRecorded * log.multiplyingFactor).toStringAsFixed(1),
            ),
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

