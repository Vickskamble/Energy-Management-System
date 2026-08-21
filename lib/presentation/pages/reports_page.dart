import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/app_config.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/calculation/savings_opportunity.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/export_service.dart';
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/month_filter_bar.dart';
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
        _buildEnergyAnalysis(entityLogs),
        const SizedBox(height: AppSpacing.lg),
        _buildCostBreakdown(currencyFmt, breakdown),
        const SizedBox(height: AppSpacing.lg),
        _buildDemandPfAnalysis(currencyFmt, breakdown),
        const SizedBox(height: AppSpacing.lg),
        _buildTodDistribution(breakdown),
        const SizedBox(height: AppSpacing.lg),
        _buildEfficiencySavings(breakdown, kpis, entityLogs),
        const SizedBox(height: AppSpacing.lg),
        _buildBillAccuracy(currencyFmt),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICAL REPORT CARDS
  // ═══════════════════════════════════════════════════════════════════

  static const _chartColors = [
    AppColors.kpiEnergy,
    AppColors.kpiDemand,
    AppColors.kpiCost,
    AppColors.kpiPower,
    AppColors.kpiEfficiency,
    Color(0xFFE879A0),
    Color(0xFF9CCC65),
    Color(0xFF26C6DA),
  ];

  /// ── Card 1: Energy Consumption Analysis ───────────────────────────
  Widget _buildEnergyAnalysis(List<EnergyLogEntity> entityLogs) {
    if (entityLogs.isEmpty) return const SizedBox.shrink();
    final totalKwh = entityLogs.fold<double>(0, (s, l) => s + l.kwh);
    final totalKvah = entityLogs.fold<double>(0, (s, l) => s + l.kvah);
    final days = entityLogs
        .map((l) => DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day))
        .toSet()
        .length;
    final dailyAvgKwh = days > 0 ? totalKwh / days : 0.0;
    final peakKwh = entityLogs.fold<double>(
      0, (m, l) => l.kwh > m ? l.kwh : m,
    );
    final avgPf = totalKvah > 0
        ? (totalKwh / totalKvah).clamp(0.0, 1.0)
        : 0.0;

    final now = DateTime.now();
    final monthDates = <DateTime>[];
    for (var i = 5; i >= 0; i--) {
      monthDates.add(DateTime(now.year, now.month - i, 1));
    }
    final monthKwh = <double>[];
    final monthKvah = <double>[];
    for (final d in monthDates) {
      final mLogs = entityLogs
          .where((e) => e.loggedAt.year == d.year && e.loggedAt.month == d.month)
          .toList();
      monthKwh.add(mLogs.fold<double>(0, (s, l) => s + l.kwh));
      monthKvah.add(mLogs.fold<double>(0, (s, l) => s + l.kvah));
    }
    final maxY = [monthKwh, monthKvah]
        .expand((l) => l)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy Consumption Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$days day(s) · ${entityLogs.length} reading(s)',
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 400 ? 2 : 4;
              final w = (constraints.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: w, child: _reportKpi('Total kWh', _fmtNum(totalKwh), AppColors.kpiEnergy)),
                  SizedBox(width: w, child: _reportKpi('Daily Avg', '${_fmtNum(dailyAvgKwh)} kWh', AppColors.kpiDemand)),
                  SizedBox(width: w, child: _reportKpi('Peak Day', '${_fmtNum(peakKwh)} kWh', AppColors.kpiCost)),
                  SizedBox(width: w, child: _reportKpi('Avg PF', avgPf.toStringAsFixed(3), AppColors.kpiPower)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: (maxY * 1.15).clamp(1.0, double.infinity),
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2A2A)
                            : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = DateFormat('MMM').format(monthDates[group.x]);
                      final val = rod.toY;
                      return BarTooltipItem(
                        '$label: ${_fmtNum(val)} kWh',
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthKwh.length || monthKwh[i] <= 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _fmtNumShort(monthKwh[i]),
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
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                            style: TextStyle(fontSize: 9, color: AppColors.dim(context)),
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
                          toY: monthKwh[i],
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          color: AppColors.kpiEnergy,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              spacing: 16,
              children: [
                _legendDot(AppColors.kpiEnergy, 'kWh'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ── Card 2: Cost Breakdown ───────────────────────────────────────
  Widget _buildCostBreakdown(NumberFormat currencyFmt, BillBreakdown breakdown) {
    final catMap = breakdown.toCategoryMap();
    final positiveEntries = catMap.entries.where((e) => e.value > 0).toList();
    final negativeEntries = catMap.entries.where((e) => e.value < 0).toList();
    final totalPositive = positiveEntries.fold<double>(0, (s, e) => s + e.value);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cost Breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Bill component analysis — estimated total',
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: _buildPieChart(positiveEntries, totalPositive),
                    ),
                    const SizedBox(height: 16),
                    _buildComponentList(currencyFmt, catMap, positiveEntries, negativeEntries),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.42,
                    height: 220,
                    child: _buildPieChart(positiveEntries, totalPositive),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildComponentList(currencyFmt, catMap, positiveEntries, negativeEntries),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: AppColors.kpiCost),
              const SizedBox(width: 8),
              Text(
                'Net Bill: ${currencyFmt.format(breakdown.netBill)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.kpiCost,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<MapEntry<String, double>> entries, double total) {
    if (entries.isEmpty || total <= 0) {
      return Center(
        child: Text('No data', style: TextStyle(color: AppColors.dim(context))),
      );
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.abs(),
              title: entries[i].value.abs() / total > 0.06
                  ? '${(entries[i].value.abs() / total * 100).toStringAsFixed(0)}%'
                  : '',
              radius: 48,
              color: _chartColors[i % _chartColors.length],
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComponentList(
    NumberFormat currencyFmt,
    Map<String, double> catMap,
    List<MapEntry<String, double>> positive,
    List<MapEntry<String, double>> negative,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < positive.length; i++)
          _costRow(positive[i].key, positive[i].value, _chartColors[i % _chartColors.length], currencyFmt),
        if (negative.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Rebates & Deductions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dim(context))),
          const SizedBox(height: 4),
          for (final e in negative)
            _costRow(e.key, e.value, AppColors.success, currencyFmt),
        ],
      ],
    );
  }

  Widget _costRow(String label, double amount, Color color, NumberFormat currencyFmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Text(
            currencyFmt.format(amount.abs()),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: amount < 0 ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }

  /// ── Card 3: Demand & Power Factor ────────────────────────────────
  Widget _buildDemandPfAnalysis(NumberFormat currencyFmt, BillBreakdown breakdown) {
    final bd = breakdown.billingDemand;
    final cd = breakdown.contractDemand;
    final pf = breakdown.powerFactor;
    final pfStatus = pf >= 0.95 ? 'Rebate 1%' : pf >= 0.90 ? 'No charge' : 'Penalty 5%';
    final pfColor = pf >= 0.95
        ? AppColors.success
        : pf >= 0.90
            ? AppColors.kpiPower
            : AppColors.danger;

    final now = DateTime.now();
    final monthDates = <DateTime>[];
    for (var i = 5; i >= 0; i--) {
      monthDates.add(DateTime(now.year, now.month - i, 1));
    }
    final monthBd = <double>[];
    final monthPf = <double>[];
    for (final d in monthDates) {
      final mLogs = _visibleLogs
          .where((e) => e.loggedAt.year == d.year && e.loggedAt.month == d.month)
          .toList();
      if (mLogs.isNotEmpty) {
        final b = BillCalculator.calculate(logs: mLogs, ratchetLogs: _allEntities);
        monthBd.add(b.billingDemand);
        monthPf.add(b.powerFactor);
      } else {
        monthBd.add(0);
        monthPf.add(0);
      }
    }
    final maxBd = monthBd.fold<double>(0, (a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demand & Power Factor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Contract utilization and PF compliance',
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _demandGauge('Billing Demand', bd, cd, 'kVA'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pfGauge(pf, pfStatus, pfColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: (math.max(maxBd, cd) * 1.15).clamp(1.0, double.infinity),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: cd > 0 ? cd : null,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == cd
                        ? AppColors.danger.withValues(alpha: 0.4)
                        : AppColors.line(context),
                    strokeWidth: value == cd ? 1.5 : 0.5,
                    dashArray: value == cd ? [6, 4] : null,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthDates.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(monthDates[i]),
                            style: TextStyle(fontSize: 9, color: AppColors.dim(context)),
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
                          toY: monthBd[i],
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          color: monthBd[i] > cd
                              ? AppColors.danger
                              : AppColors.kpiDemand,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.kpiDemand, 'Billing Demand'),
              const SizedBox(width: 16),
              _legendDot(AppColors.danger, 'CD ($cd kVA)', dashed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demandGauge(String label, double value, double max, String unit) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kpiDemand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.dim(context))),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.line(context),
              color: pct > 0.85 ? AppColors.danger : AppColors.kpiDemand,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% of $max $unit',
            style: TextStyle(fontSize: 10, color: AppColors.dim(context)),
          ),
        ],
      ),
    );
  }

  Widget _pfGauge(double pf, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Power Factor', style: TextStyle(fontSize: 11, color: AppColors.dim(context))),
          const SizedBox(height: 6),
          Text(
            pf.toStringAsFixed(3),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pf,
              minHeight: 6,
              backgroundColor: AppColors.line(context),
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Card 4: ToD Distribution ────────────────────────────────────
  Widget _buildTodDistribution(BillBreakdown breakdown) {
    final zoneUnits = breakdown.todZoneUnits;
    final zoneCharges = breakdown.todZoneCharges;
    final netTod = breakdown.todCharges;
    if (zoneUnits.isEmpty) return const SizedBox.shrink();

    final totalUnits = zoneUnits.values.fold<double>(0, (s, v) => s + v);
    if (totalUnits <= 0) return const SizedBox.shrink();

    final zones = ['A', 'B', 'C', 'D'];
    final zoneLabels = {'A': 'Night (00-06)', 'B': 'Morning (06-09)', 'C': 'Day (09-17)', 'D': 'Evening (17-24)'};
    final zoneColors = {
      'A': const Color(0xFF5C6BC0),
      'B': const Color(0xFF42A5F5),
      'C': const Color(0xFFFFCA28),
      'D': const Color(0xFFEF5350),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time-of-Day Distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Slot-wise consumption and ToD charges',
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final pieEntries = zones
                  .where((z) => (zoneUnits[z] ?? 0) > 0)
                  .map((z) => MapEntry(z, zoneUnits[z]!))
                  .toList();
              final pieTotal = pieEntries.fold<double>(0, (s, e) => s + e.value);

              if (isNarrow) {
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: [
                            for (var i = 0; i < pieEntries.length; i++)
                              PieChartSectionData(
                                value: pieEntries[i].value,
                                title: pieEntries[i].value / pieTotal > 0.06
                                    ? '${(pieEntries[i].value / pieTotal * 100).toStringAsFixed(0)}%'
                                    : '',
                                radius: 48,
                                color: zoneColors[pieEntries[i].key],
                                titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildZoneList(zones, zoneLabels, zoneColors, zoneUnits, zoneCharges, totalUnits),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.38,
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          for (var i = 0; i < pieEntries.length; i++)
                            PieChartSectionData(
                              value: pieEntries[i].value,
                              title: pieEntries[i].value / pieTotal > 0.06
                                  ? '${(pieEntries[i].value / pieTotal * 100).toStringAsFixed(0)}%'
                                  : '',
                              radius: 48,
                              color: zoneColors[pieEntries[i].key],
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildZoneList(zones, zoneLabels, zoneColors, zoneUnits, zoneCharges, totalUnits),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                netTod <= 0 ? Icons.savings_outlined : Icons.trending_up,
                size: 18,
                color: netTod <= 0 ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                'Net ToD: ${netTod <= 0 ? '-' : '+'}₹${netTod.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: netTod <= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                netTod <= 0 ? '(savings from solar window)' : '(peak-hour surcharge)',
                style: TextStyle(fontSize: 11, color: AppColors.dim(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneList(
    List<String> zones,
    Map<String, String> zoneLabels,
    Map<String, Color> zoneColors,
    Map<String, double> zoneUnits,
    Map<String, double> zoneCharges,
    double totalUnits,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final z in zones)
          if ((zoneUnits[z] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: zoneColors[z],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zone $z — ${zoneLabels[z]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_fmtNum(zoneUnits[z]!)} units (${(zoneUnits[z]! / totalUnits * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(fontSize: 10, color: AppColors.dim(context)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(zoneCharges[z] ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (zoneCharges[z] ?? 0) < 0 ? AppColors.success : null,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// ── Card 5: Efficiency & Savings ─────────────────────────────────
  Widget _buildEfficiencySavings(
    BillBreakdown breakdown,
    BusinessKpi kpis,
    List<EnergyLogEntity> entityLogs,
  ) {
    final lf = breakdown.loadFactor;
    final lfPct = (lf * 100);
    final lfStatus = lfPct >= 75
        ? 'Incentive eligible'
        : lfPct >= 50
            ? 'Below threshold'
            : 'Low LF';

    final opportunities = SavingOpportunityGenerator.generate(breakdown);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Efficiency & Savings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Performance scores and savings opportunities',
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 400 ? 2 : 3;
              final w = (constraints.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: w,
                    child: _efficiencyCard(
                      'Load Factor',
                      '${lfPct.toStringAsFixed(1)}%',
                      lfStatus,
                      lfPct >= 75 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _efficiencyCard(
                      'Bill Health',
                      '${kpis.billHealthScore.toStringAsFixed(0)}/100',
                      kpis.billHealthScore >= 80 ? 'Good' : 'Needs attention',
                      kpis.billHealthScore >= 80 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _efficiencyCard(
                      'Energy Score',
                      '${kpis.energyScore.toStringAsFixed(0)}/100',
                      kpis.energyScore >= 70 ? 'Efficient' : 'Can improve',
                      kpis.energyScore >= 70 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
          if (opportunities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Savings Opportunities',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.dim(context),
              ),
            ),
            const SizedBox(height: 8),
            for (final opp in opportunities.take(3))
              _savingsOpportunityRow(opp),
          ],
        ],
      ),
    );
  }

  Widget _efficiencyCard(String label, String value, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.dim(context))),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savingsOpportunityRow(SavingOpportunity opp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opp.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  opp.description,
                  style: TextStyle(fontSize: 11, color: AppColors.dim(context)),
                ),
              ],
            ),
          ),
          Text(
            '₹${opp.monthlySavings.toStringAsFixed(0)}/mo',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  /// ── Shared helpers ───────────────────────────────────────────────
  Widget _reportKpi(String label, String value, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.dim(context))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.statusText(color, dark),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.dim(context))),
      ],
    );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(1);
  }

  String _fmtNumShort(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
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
}

