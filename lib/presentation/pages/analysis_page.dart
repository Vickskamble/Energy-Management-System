import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/month_filter_bar.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../widgets/tour_keys.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';
import '../widgets/readings_preview_sheet.dart';

class AnalysisPage extends StatelessWidget {
  final MonthFilterController monthFilter;

  const AnalysisPage({super.key, required this.monthFilter});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnergyBloc, EnergyState>(
      builder: (context, state) {
        return switch (state) {
          EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(
            message: 'Loading data...',
          ),
          EnergySuccess(:final logs) => _AnalysisContent(
            logs: logs,
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

class _AnalysisContent extends StatefulWidget {
  final List<dynamic> logs;
  final MonthFilterController monthFilter;
  const _AnalysisContent({required this.logs, required this.monthFilter});

  @override
  State<_AnalysisContent> createState() => _AnalysisContentState();
}

class _AnalysisContentState extends State<_AnalysisContent> {
  static const int _pageSize = 25;
  late int _visibleCount;
  String? _selectedMeter;
  String? _selectedSite;
  Map<String, String> _meterSites = {};
  Map<String, double> _meterKwhTargets = {};

  MonthFilterValue get _selection => widget.monthFilter.value;

  @override
  void initState() {
    super.initState();
    _visibleCount = _pageSize;
    _loadMeterSites();
    context.read<MeterRepository>().addListener(_loadMeterSites);
    widget.monthFilter.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant _AnalysisContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthFilter != widget.monthFilter) {
      oldWidget.monthFilter.removeListener(_onFilterChanged);
      widget.monthFilter.addListener(_onFilterChanged);
    }
    if (oldWidget.logs.length != widget.logs.length) {
      _visibleCount = _pageSize;
    }
  }

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_loadMeterSites);
    widget.monthFilter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMeterSites() async {
    try {
      final meters = await context.read<MeterRepository>().getAllMeters();
      if (!mounted) return;
      setState(() {
        _meterSites = {
          for (final m in meters) m.name: m.site,
        };
        _meterKwhTargets = {
          for (final m in meters)
            if (m.dailyKwhTarget > 0) m.name: m.dailyKwhTarget,
        };
      });
    } catch (_) {
      // Site filter is best-effort — logs still render without it.
    }
  }

  List<EnergyLogEntity> get _entities => widget.logs.cast<EnergyLogEntity>();

  /// Logs filtered by the selected site (Issue 7E).
  List<EnergyLogEntity> get _siteEntities {
    if (_selectedSite == null) return _entities;
    final meterNames = <String>{
      for (final e in _meterSites.entries)
        if (e.value == _selectedSite) e.key,
    };
    if (meterNames.isEmpty) return const [];
    return _entities.where((e) => meterNames.contains(e.meterName)).toList();
  }

  List<String> get _siteNames {
    final names = _meterSites.values.toSet().toList()..sort();
    return names;
  }

  /// Meters for the chips row: every meter registered for the selected site
  /// (even without readings) plus any meter still present in historical log
  /// data — so added meters always appear in the selector.
  List<String> get _meterNames {
    final names = <String>{
      for (final e in _meterSites.entries)
        if (_selectedSite == null || e.value == _selectedSite) e.key,
      for (final e in _siteEntities) e.meterName,
    }.toList()..sort();
    return names;
  }

  /// Distinct (year, month) keys present in the data, newest first — drives
  /// the shared month filter bar.
  List<DateTime> get _monthKeys {
    final keys = <String, DateTime>{};
    for (final e in _siteEntities) {
      keys['${e.loggedAt.year}-${e.loggedAt.month}'] = DateTime(
        e.loggedAt.year,
        e.loggedAt.month,
      );
    }
    final list = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<EnergyLogEntity> get _filtered {
    final meterFiltered = _selectedMeter == null
        ? _siteEntities
        : _siteEntities.where((e) => e.meterName == _selectedMeter).toList();
    return meterFiltered
        .where((e) => _selection.matches(e.loggedAt))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // No meters and no readings at all → nothing to show.
    if (_entities.isEmpty && _siteNames.isEmpty) {
      return KeyedSubtree(
        key: kTourAnalysisKey,
        child: const AppEmptyState(
          icon: Icons.analytics_rounded,
          title: 'No readings recorded yet',
          subtitle: 'Add a meter and readings to see analysis',
        ),
      );
    }

    return KeyedSubtree(
      key: kTourAnalysisKey,
      child: RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (_siteNames.isNotEmpty) ...[
            _buildSiteSelector(),
            const SizedBox(height: 12),
          ],
          if (_meterNames.isNotEmpty) ...[
            _buildMeterSelector(),
            const SizedBox(height: 12),
            _buildMonthSelector(),
            const SizedBox(height: 12),
            _buildMeterTrends(),
            const SizedBox(height: 24),
            _buildMdBreachPrediction(),
            const SizedBox(height: 24),
            _buildAnomalyHighlights(),
            const SizedBox(height: 24),
          ],
          if (_filtered.isNotEmpty) ...[
            _buildBillAnalysis(),
            const SizedBox(height: 24),
            _buildPowerQualityTrends(),
            const SizedBox(height: 24),
            _buildMonthComparison(),
            const SizedBox(height: 24),
          ] else if (_entities.isNotEmpty) ...[
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No readings found for this period',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
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
      ),
    );
  }

  // ── Site selector dropdown (Issue 7E) ────────────────────────────────
  Widget _buildSiteSelector() {
    final names = _siteNames;
    final value =
        (_selectedSite != null && names.contains(_selectedSite))
        ? _selectedSite!
        : 'All Sites';
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Site',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  'All Sites',
                  for (final site in names) site,
                ]
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedSite = (v == 'All Sites') ? null : v;
                  _selectedMeter = null;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Meter selector dropdown ──────────────────────────────────────────
  Widget _buildMeterSelector() {
    final names = _meterNames;
    final value = (_selectedMeter != null && names.contains(_selectedMeter))
        ? _selectedMeter!
        : 'All Meters';
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.speed_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Meter',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  'All Meters',
                  for (final name in names) name,
                ]
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedMeter = (v == 'All Meters') ? null : v;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month filter + export (Issue 4F / 5) ──────────────────────────────
  Widget _buildMonthSelector() {
    return Row(
      children: [
        Expanded(
          child: MonthFilterBar(
            controller: widget.monthFilter,
            availableMonths: _monthKeys,
          ),
        ),
        const SizedBox(width: 12),
        AppButtonOutline(
          label: 'Export PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () async {
            try {
              await PdfReportService.exportPdf(
                logs: _filtered,
                title: 'Analysis Report',
                subtitle:
                    '${_filtered.length} reading(s) — ${_selection.label}',
              );
            } catch (e) {
              AppLogger.e('Analysis PDF export failed', e);
              if (mounted) {
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
      ],
    );
  }

  // ── Bill breakdown (Issue 5 — was only on Dashboard) ──────────────────
  Widget _buildBillAnalysis() {
    final breakdown = BillCalculator.calculate(
      logs: _filtered,
      ratchetLogs: _entities,
    );
    if (breakdown.totalUnits <= 0) return const SizedBox.shrink();
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final rows = <(String, double, Color)>[
      ('Energy Charges', breakdown.energyCharges, AppColors.kpiEnergy),
      ('Demand Charges', breakdown.demandCharges, AppColors.kpiDemand),
      ('FAC', breakdown.facCharges, AppColors.textPrimary),
      ('Wheeling', breakdown.wheelingCharges, AppColors.textPrimary),
      ('Electricity Duty', breakdown.electricityDuty, AppColors.textPrimary),
      ('Taxes', breakdown.taxes, AppColors.textPrimary),
      ('PF Rebate', -breakdown.pfRebate, AppColors.kpiSavings),
      ('PF Surcharge', breakdown.pfSurcharge, AppColors.danger),
      ('Subsidy', -breakdown.subsidy, AppColors.kpiSavings),
      if (breakdown.icrRebate > 0)
        ('ICR Rebate', -breakdown.icrRebate, AppColors.kpiSavings),
      if (breakdown.lfIncentive > 0)
        ('LF Incentive', -breakdown.lfIncentive, AppColors.kpiSavings),
      if (breakdown.ppdRebate > 0)
        ('PPD Rebate', -breakdown.ppdRebate, AppColors.kpiSavings),
      if (breakdown.bulkRebate > 0)
        ('Bulk Rebate', -breakdown.bulkRebate, AppColors.kpiSavings),
      if (breakdown.arrearsDpc > 0)
        ('Arrears/DPC', breakdown.arrearsDpc, AppColors.danger),
      if (breakdown.roundingAdjustment != 0)
        ('Rounding', breakdown.roundingAdjustment, AppColors.textPrimary),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${_filtered.length} reading(s) — detailed breakdown',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 24),
          for (final (label, amount, color) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(
                    '${amount < 0 ? '−' : ''}${currencyFmt.format(amount.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'Net Bill (est.)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                currencyFmt.format(breakdown.netBill),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.kpiCost,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total Units: ${breakdown.totalUnits.toStringAsFixed(0)} kWh'
            '  ·  Billing Demand: ${breakdown.billingDemand.toStringAsFixed(1)} kVA'
            '  ·  Avg Unit Cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── PF + Load Factor trends (Issue 5) ─────────────────────────────────
  Widget _buildPowerQualityTrends() {
    final logs = _filtered.toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    if (logs.length < 2) return const SizedBox.shrink();
    final recent = logs.length > 30 ? logs.sublist(logs.length - 30) : logs;

    // Tap a trend point → preview all readings of that day.
    void showDayReadings(EnergyLogEntity log) {
      final sameDay =
          _filtered
              .where(
                (l) =>
                    l.loggedAt.year == log.loggedAt.year &&
                    l.loggedAt.month == log.loggedAt.month &&
                    l.loggedAt.day == log.loggedAt.day,
              )
              .toList()
            ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      showReadingsPreviewSheet(
        context,
        title:
            'Readings · ${DateFormat('d MMM yyyy').format(log.loggedAt)}',
        logs: sameDay.isEmpty ? [log] : sameDay,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Power Quality Trends',
          subtitle: 'Last ${recent.length} readings',
        ),
        const SizedBox(height: 8),
        if (MediaQuery.of(context).size.width < 600)
          Column(
            children: [
              AppCard(
                child: _miniLineChartMulti(
                  title: 'Power Factor',
                  series: [
                    _ChartSeries(
                      label: 'PF',
                      color: AppColors.kpiEfficiency,
                      values: recent.map((e) => e.powerFactor).toList(),
                    ),
                  ],
                  unit: '',
                  onTapPoint: (i) => showDayReadings(recent[i]),
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: _miniLineChartMulti(
                  title: 'Load Factor',
                  series: [
                    _ChartSeries(
                      label: 'LF',
                      color: AppColors.kpiPower,
                      values: recent.map((e) => e.loadFactor).toList(),
                    ),
                  ],
                  unit: '',
                  onTapPoint: (i) => showDayReadings(recent[i]),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCard(
                  child: _miniLineChartMulti(
                    title: 'Power Factor',
                    series: [
                      _ChartSeries(
                        label: 'PF',
                        color: AppColors.kpiEfficiency,
                        values: recent.map((e) => e.powerFactor).toList(),
                      ),
                    ],
                    unit: '',
                    onTapPoint: (i) => showDayReadings(recent[i]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: _miniLineChartMulti(
                    title: 'Load Factor',
                    series: [
                      _ChartSeries(
                        label: 'LF',
                        color: AppColors.kpiPower,
                        values: recent.map((e) => e.loadFactor).toList(),
                      ),
                    ],
                    unit: '',
                    onTapPoint: (i) => showDayReadings(recent[i]),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Month-over-month comparison (Issue 5 / 4F) ────────────────────────
  Widget _buildMonthComparison() {
    if (_filtered.isEmpty) return const SizedBox.shrink();
    // "This Month" has month == null but should still compare vs last month.
    final effectiveMonth = _selection.month ??
        (_selection.isCurrent
            ? DateTime(DateTime.now().year, DateTime.now().month)
            : null);
    if (effectiveMonth == null) return const SizedBox.shrink();
    final refMonth = effectiveMonth;
    final prevStart = DateTime(refMonth.year, refMonth.month - 1, 1);
    final previous = _entities
        .where(
          (e) =>
              e.loggedAt.year == prevStart.year &&
              e.loggedAt.month == prevStart.month &&
              (_selectedMeter == null || e.meterName == _selectedMeter),
        )
        .toList();
    if (previous.isEmpty) return const SizedBox.shrink();

    final comparison = BillCalculator.compare(
      BillCalculator.calculate(logs: _filtered, ratchetLogs: _entities),
      BillCalculator.calculate(logs: previous, ratchetLogs: _entities),
    );
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final current = comparison.current;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month Comparison',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('MMM yyyy').format(refMonth)} vs '
            '${DateFormat('MMM yyyy').format(prevStart)}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 24),
          _deltaRow(
            'Est. Bill',
            currencyFmt.format(current.netBill),
            comparison.billDifference,
            comparison.billPercentChange,
          ),
          _deltaRow(
            'Units (kWh)',
            current.totalUnits.toStringAsFixed(0),
            comparison.unitDifference,
            comparison.unitPercentChange,
          ),
          _deltaRow(
            'Billing Demand (kVA)',
            current.billingDemand.toStringAsFixed(1),
            comparison.demandDifference,
            comparison.demandPercentChange,
          ),
          _deltaRow(
            'Power Factor',
            current.powerFactor.toStringAsFixed(3),
            comparison.pfDifference,
            comparison.pfDifference * 100,
            higherIsBetter: true,
          ),
        ],
      ),
    );
  }

  Widget _deltaRow(
    String label,
    String currentValue,
    double diff,
    double pct, {
    bool higherIsBetter = false,
  }) {
    final up = diff > 0;
    final good = diff == 0 ? true : (higherIsBetter ? up : !up);
    final color = diff == 0
        ? AppColors.textSecondary
        : (good ? AppColors.success : AppColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(
            currentValue,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Text(
            diff == 0 ? '—' : '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Per-meter trend charts ─────────────────────────────────────────────
  // Monthly overview by default; when a month is selected the charts switch
  // to a DAILY breakdown of that month (kWh = sum per day, kVA = max per
  // day) so it is obvious which day was high or low. Multi-series when
  // "All Meters" (Issue 4E).
  Widget _buildMeterTrends() {
    final target = _selectedMeter;
    final names = target != null
        ? <String>[target]
        : _siteEntities.map((e) => e.meterName).toSet().toList();
    const palette = [
      AppColors.primary,
      AppColors.warning,
      AppColors.kpiSavings,
      AppColors.kpiEfficiency,
      AppColors.kpiPower,
      AppColors.kpiDemand,
    ];

    // "This Month" keeps `month == null` (so it auto-follows the live month);
    // treat it exactly like a picked month so the chart shows a DAILY breakdown
    // (multiple points) instead of collapsing to a single monthly point.
    final effectiveMonth = _selection.month ??
        (_selection.isCurrent
            ? DateTime(DateTime.now().year, DateTime.now().month)
            : null);
    final daily = effectiveMonth != null;

    // Union axis: days of the selected month, or every (year, month) in
    // history — every meter's series aligns to the same x positions.
    final axisKeys = daily
        ? (_siteEntities
                .where((e) => _selection.matches(e.loggedAt))
                .map((e) => e.loggedAt.day)
                .toSet()
                .toList()
              ..sort())
        : (_siteEntities
                .where((e) => _selection.matches(e.loggedAt))
                .map((e) => e.loggedAt.year * 12 + e.loggedAt.month - 1)
                .toSet()
                .toList()
              ..sort());
    if (axisKeys.isEmpty) return const SizedBox.shrink();

    final xLabels = <String>[];
    if (daily) {
      final m = effectiveMonth;
      xLabels.addAll(
        [
          for (final d in axisKeys)
            DateFormat('d MMM').format(DateTime(m.year, m.month, d)),
        ],
      );
    } else {
      xLabels.addAll(
        [
          for (final k in axisKeys)
            DateFormat('MMM yy').format(DateTime(k ~/ 12, (k % 12) + 1)),
        ],
      );
    }
    final xLabelStep = daily
        ? (axisKeys.length / 8).ceil().clamp(1, 99)
        : (axisKeys.length / 10).ceil().clamp(1, 99);

    final kwhSeries = <_ChartSeries>[];
    final mdSeries = <_ChartSeries>[];
    for (var i = 0; i < names.length; i++) {
      final logs = _siteEntities
          .where((e) => e.meterName == names[i])
          .toList();
      if (logs.isEmpty) continue;

      final kwhMap = <int, double>{};
      final mdMap = <int, double>{};
      for (final e in logs) {
        if (daily && !_selection.matches(e.loggedAt)) continue;
        final k = daily
            ? e.loggedAt.day
            : e.loggedAt.year * 12 + e.loggedAt.month - 1;
        final kw = e.kwh * e.multiplyingFactor;
        kwhMap.update(k, (v) => v + kw, ifAbsent: () => kw);
        final md = e.mdRecorded * e.multiplyingFactor;
        mdMap.update(k, (v) => md > v ? md : v, ifAbsent: () => md);
      }
      if (kwhMap.isEmpty) continue;

      final color = palette[i % palette.length];
      kwhSeries.add(
        _ChartSeries(
          label: names[i],
          color: color,
          values: [for (final k in axisKeys) kwhMap[k] ?? 0],
        ),
      );
      mdSeries.add(
        _ChartSeries(
          label: names[i],
          color: color,
          values: [for (final k in axisKeys) mdMap[k] ?? 0],
        ),
      );
    }
    if (kwhSeries.isEmpty) return const SizedBox.shrink();

    final periodLabel = daily
        ? 'Daily — ${_selection.label}'
        : 'Monthly — all readings';

    // Daily budget for the visible meters — dashed cross line on the daily
    // kWh chart (client asked: each day's kWh against the daily target).
    final dailyTarget = daily
        ? names.fold(0.0, (sum, n) => sum + (_meterKwhTargets[n] ?? 0))
        : 0.0;

    // Tap a trend point → preview all readings of that day / month.
    void showBucketReadings(int index) {
      if (index < 0 || index >= axisKeys.length) return;
      final k = axisKeys[index];
      if (daily) {
        final m = effectiveMonth;
        final logs =
            _siteEntities
                .where(
                  (e) =>
                      e.loggedAt.year == m.year &&
                      e.loggedAt.month == m.month &&
                      e.loggedAt.day == k,
                )
                .toList()
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        showReadingsPreviewSheet(
          context,
          title:
              'Readings · ${DateFormat('d MMM').format(DateTime(m.year, m.month, k))}',
          logs: logs,
        );
      } else {
        final year = k ~/ 12;
        final month = (k % 12) + 1;
        final logs =
            _siteEntities
                .where(
                  (e) =>
                      e.loggedAt.year == year && e.loggedAt.month == month,
                )
                .toList()
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        showReadingsPreviewSheet(
          context,
          title: 'Readings · ${DateFormat('MMM yy').format(DateTime(year, month))}',
          logs: logs,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Trends',
          subtitle: '$periodLabel — ${target ?? 'all meters'}',
        ),
        const SizedBox(height: 8),
        if (MediaQuery.of(context).size.width < 600)
          Column(
            children: [
              AppCard(
                child: _miniLineChartMulti(
                  title: 'kWh Consumption',
                  series: kwhSeries,
                  unit: 'kWh',
                  xLabels: xLabels,
                  xLabelStep: xLabelStep,
                  onTapPoint: showBucketReadings,
                  targetKwhPerDay: dailyTarget,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: _miniLineChartMulti(
                  title: 'Max Demand (kVA)',
                  series: mdSeries,
                  unit: 'kVA',
                  xLabels: xLabels,
                  xLabelStep: xLabelStep,
                  onTapPoint: showBucketReadings,
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCard(
                  child: _miniLineChartMulti(
                    title: 'kWh Consumption',
                    series: kwhSeries,
                    unit: 'kWh',
                    xLabels: xLabels,
                    xLabelStep: xLabelStep,
                    onTapPoint: showBucketReadings,
                    targetKwhPerDay: dailyTarget,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: _miniLineChartMulti(
                    title: 'Max Demand (kVA)',
                    series: mdSeries,
                    unit: 'kVA',
                    xLabels: xLabels,
                    xLabelStep: xLabelStep,
                    onTapPoint: showBucketReadings,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── MD breach prediction (Issue 5) ────────────────────────────────────
  /// "When will MD breach at this rate" — from the latest month MD growth rate.
  Widget _buildMdBreachPrediction() {
    final now = DateTime.now();
    final monthLogs = _siteEntities
        .where(
          (e) => e.loggedAt.year == now.year && e.loggedAt.month == now.month,
        )
        .toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    if (monthLogs.isEmpty || monthLogs.length < 2) {
      return const SizedBox.shrink();
    }

    final contract = monthLogs.last.contractDemand;
    if (contract <= 0) return const SizedBox.shrink();
    final threshold = contract * AppConstants.mdWarningRatio;
    final peakMd = monthLogs
        .map((e) => e.mdRecorded * e.multiplyingFactor)
        .reduce((a, b) => a > b ? a : b);

    // MD growth rate (kVA/day) — least-squares over (days, md).
    final start = monthLogs.first.loggedAt;
    var sumX = 0.0, sumY = 0.0, sumXy = 0.0, sumXx = 0.0;
    final n = monthLogs.length;
    for (final e in monthLogs) {
      final x = e.loggedAt.difference(start).inDays.toDouble();
      final y = e.mdRecorded * e.multiplyingFactor;
      sumX += x;
      sumY += y;
      sumXy += x * y;
      sumXx += x * x;
    }
    final denom = n * sumXx - sumX * sumX;
    final rate = denom.abs() < 0.0001 ? 0.0 : (n * sumXy - sumX * sumY) / denom;

    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
    final gap = threshold - peakMd;

    String title;
    String body;
    Color color;
    IconData icon;
    if (peakMd >= contract) {
      title = 'MD Breach — ${peakMd.toStringAsFixed(0)} kVA > contract ${contract.toStringAsFixed(0)} kVA';
      body =
          'This month peak demand has crossed the contract limit — an excess demand penalty will apply.';
      color = AppColors.danger;
      icon = Icons.error_rounded;
    } else if (peakMd >= threshold) {
      title = 'MD ${peakMd.toStringAsFixed(0)} kVA — at breach threshold';
      body =
          'Current peak is at ${(AppConstants.mdWarningRatio * 100).toStringAsFixed(0)}% of contract. Shift non-essential loads to off-peak hours.';
      color = AppColors.warning;
      icon = Icons.warning_amber_rounded;
    } else if (rate > 0.01) {
      final daysToBreach = gap / rate;
      if (daysToBreach <= daysLeft) {
        final breachDate = now.add(Duration(days: daysToBreach.ceil()));
        title =
            'Breach expected on ${DateFormat('d MMM').format(breachDate)} at this rate';
        body =
            'MD is rising ${rate.toStringAsFixed(1)} kVA/day — it will cross the '
            '${threshold.toStringAsFixed(0)} kVA threshold in '
            '${daysToBreach.ceil().toString()} days (contract ${contract.toStringAsFixed(0)} kVA).';
        color = AppColors.warning;
        icon = Icons.trending_up_rounded;
      } else {
        title = 'No risk of MD breach';
        body =
            'Peak ${peakMd.toStringAsFixed(0)} kVA is well below the '
            '${contract.toStringAsFixed(0)} kVA contract; month-end remains '
            'safe even at ${rate.toStringAsFixed(1)} kVA/day growth.';
        color = AppColors.success;
        icon = Icons.verified_rounded;
      }
    } else {
      title = 'MD is under control';
      body =
          'Peak is ${peakMd.toStringAsFixed(0)} kVA — '
          '${((peakMd / contract) * 100).toStringAsFixed(0)}% of the '
          '${contract.toStringAsFixed(0)} kVA contract.';
      color = AppColors.success;
      icon = Icons.verified_rounded;
    }

    return AppCard(
      color: color.withValues(alpha: 0.04),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rule-based anomaly highlights (Issue 5) ───────────────────────────
  /// Month-level consumption spike/dip vs pichle months ka average.
  Widget _buildAnomalyHighlights() {
    final scope = _selectedMeter != null
        ? _siteEntities.where((e) => e.meterName == _selectedMeter).toList()
        : _siteEntities;
    if (scope.length < 2) return const SizedBox.shrink();

    final monthlyUnits = <String, double>{};
    for (final e in scope) {
      final key =
          '${e.loggedAt.year.toString().padLeft(4, '0')}-${e.loggedAt.month.toString().padLeft(2, '0')}';
      monthlyUnits[key] =
          (monthlyUnits[key] ?? 0) + e.kwh * e.multiplyingFactor;
    }

    final months = monthlyUnits.keys.toList()..sort();
    if (months.length < 2) return const SizedBox.shrink();

    final anomalies = <({String label, double deviation, bool up})>[];
    for (var i = 0; i < months.length; i++) {
      final others = <double>[
        for (var j = 0; j < months.length; j++)
          if (j != i) monthlyUnits[months[j]]!,
      ];
      final avg = others.reduce((a, b) => a + b) / others.length;
      if (avg <= 0) continue;
      final deviation = (monthlyUnits[months[i]]! - avg) / avg * 100;
      if (deviation.abs() >= 30) {
        final parts = months[i].split('-');
        final label = DateFormat(
          'MMM yyyy',
        ).format(DateTime(int.parse(parts[0]), int.parse(parts[1]), 1));
        anomalies.add(
          (label: label, deviation: deviation, up: deviation > 0),
        );
      }
    }
    if (anomalies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Anomaly Highlights',
          subtitle: 'Months jahan consumption average se 30%+ deviate hua',
        ),
        const SizedBox(height: 8),
        for (final a in anomalies) ...[
          AppCard(
            color: (a.up ? AppColors.warning : AppColors.kpiEnergy).withValues(
              alpha: 0.05,
            ),
            child: Row(
              children: [
                Icon(
                  a.up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: a.up ? AppColors.warning : AppColors.kpiEnergy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${a.label} — ${a.deviation.toStringAsFixed(0)}% ${a.up ? 'zyada' : 'kam'} consumption',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  a.up ? 'SPIKE' : 'DIP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: a.up ? AppColors.warning : AppColors.kpiEnergy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _miniLineChartMulti({
    required String title,
    required List<_ChartSeries> series,
    required String unit,
    List<String>? xLabels,
    int xLabelStep = 1,
    void Function(int index)? onTapPoint,
    double targetKwhPerDay = 0,
  }) {
    final rawMax = series
        .expand((s) => s.values)
        .fold(0.0, (a, b) => a > b ? a : b);
    var maxY = (rawMax * 1.2).clamp(1.0, double.infinity);
    if (targetKwhPerDay > 0) {
      if (maxY < targetKwhPerDay * 1.18) {
        maxY = targetKwhPerDay * 1.18;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (series.first.values.length - 1)
                  .toDouble()
                  .clamp(1.0, double.infinity),
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
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: xLabels != null && xLabels.isNotEmpty,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (xLabels == null ||
                          i < 0 ||
                          i >= xLabels.length ||
                          (xLabelStep > 1 && i % xLabelStep != 0)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          xLabels[i],
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < s.values.length; i++)
                        FlSpot(i.toDouble(), s.values[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: s.color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: series.length == 1,
                      color: s.color.withValues(alpha: 0.08),
                    ),
                  ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: targetKwhPerDay > 0
                    ? [
                        HorizontalLine(
                          y: targetKwhPerDay,
                          color: AppColors.danger,
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        ),
                      ]
                    : const [],
              ),
              lineTouchData: LineTouchData(
                touchCallback:
                    onTapPoint == null
                        ? null
                        : (event, response) {
                            if (event is FlTapUpEvent &&
                                response != null &&
                                response.lineBarSpots != null &&
                                response.lineBarSpots!.isNotEmpty) {
                              final idx = response.lineBarSpots!.first.x
                                  .toInt();
                              if (idx >= 0 &&
                                  idx < series.first.values.length) {
                                onTapPoint(idx);
                              }
                            }
                          },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map(
                        (spot) {
                          final label = xLabels != null &&
                                  spot.x >= 0 &&
                                  spot.x < xLabels.length
                              ? '${xLabels[spot.x.toInt()]}  '
                              : '';
                          return LineTooltipItem(
                            '$label${spot.y.toStringAsFixed(1)} $unit',
                            TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final s in series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        if (targetKwhPerDay > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(18, 4),
                painter: _DashPainter(AppColors.danger),
              ),
              const SizedBox(width: 6),
              Text(
                'Daily target ${targetKwhPerDay.toStringAsFixed(0)} kWh/day',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
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
                              if (log.currentKwh != null ||
                                  log.currentKvah != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Reading: '
                                  '${log.currentKwh?.toStringAsFixed(1) ?? '—'} kWh · '
                                  '${log.currentKvah?.toStringAsFixed(1) ?? '—'} kVAh',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
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
                          (log.mdRecorded * log.multiplyingFactor)
                              .toStringAsFixed(1),
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
    final rkvarhLagCtrl = TextEditingController(
      text: log.rkvarhLag.toStringAsFixed(2),
    );
    final rkvarhLeadCtrl = TextEditingController(
      text: log.rkvarhLead.toStringAsFixed(2),
    );
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: rkvarhLagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'rkVARh (Lag)',
                              prefixIcon: Icon(Icons.warning_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return double.tryParse(v.trim()) == null
                                  ? 'Enter a valid number'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: rkvarhLeadCtrl,
                            decoration: const InputDecoration(
                              labelText: 'rkVARh (Lead)',
                              prefixIcon: Icon(Icons.check_circle_outline),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return double.tryParse(v.trim()) == null
                                  ? 'Enter a valid number'
                                  : null;
                            },
                          ),
                        ),
                      ],
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
                    currentKwh: log.currentKwh,
                    currentKvah: log.currentKvah,
                    rkvarhLag: double.tryParse(rkvarhLagCtrl.text.trim()) ?? 0,
                    rkvarhLead: double.tryParse(rkvarhLeadCtrl.text.trim()) ??
                        0,
                    mdRecorded: double.parse(mdCtrl.text.trim()),
                    loggedAt: date,
                    contractDemand: log.contractDemand,
                    userId: log.userId,
                    isSynced: log.isSynced,
                    multiplyingFactor: log.multiplyingFactor,
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

class _ChartSeries {
  const _ChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 4.0;
    const gap = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0.0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}
