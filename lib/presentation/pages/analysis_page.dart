import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/calculation/bill_calculator.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/pdf_report_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/month_filter_bar.dart';

import '../../data/repositories/meter_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';
import '../widgets/readings_preview_sheet.dart';
import '../widgets/tod_shift_section.dart';

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
  String? _selectedMeter;
  String? _selectedSite;
  Map<String, String> _meterSites = {};
  Map<String, double> _meterKwhTargets = {};

  MonthFilterValue get _selection => widget.monthFilter.value;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _dimText =>
      _isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

  Color get _line => _isDark ? AppColors.borderDark : AppColors.borderLight;

  @override
  void initState() {
    super.initState();
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
      return const AppEmptyState(
        icon: Icons.analytics_rounded,
        title: 'No readings recorded yet',
        subtitle: 'Add a meter and readings to see analysis',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (_siteNames.isNotEmpty || _meterNames.isNotEmpty) ...[
            _buildFilterRow(),
            const SizedBox(height: 12),
          ],
          if (_meterNames.isNotEmpty) ...[
            _buildMeterTrends(),
            const SizedBox(height: 24),
            _buildMdBreachPrediction(),
            const SizedBox(height: 24),
            _buildSystemIssues(),
            const SizedBox(height: 24),
          ],
          if (_filtered.isNotEmpty) ...[
            TodShiftSection(
              logs: _filtered,
              siteLabel: _siteNames.length == 1
                  ? _siteNames.first
                  : 'All Sites',
            ),
            const SizedBox(height: 24),
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
                      color: _dimText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ── Compact site + meter + month filters (one compact row) ────────────────
  Widget _compactDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    int flex = 2,
  }) {
    return Expanded(
      flex: flex,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: Icon(icon, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFilterRow() {
    final children = <Widget>[
      if (_siteNames.isNotEmpty)
        _compactDropdown(
          label: 'Site',
          icon: Icons.location_on_outlined,
          value: (_selectedSite != null && _siteNames.contains(_selectedSite))
              ? _selectedSite!
              : 'All Sites',
          items: ['All Sites', ..._siteNames],
          onChanged: (v) => setState(() {
            _selectedSite = (v == 'All Sites') ? null : v;
            _selectedMeter = null;
          }),
          flex: 2,
        ),
      if (_meterNames.isNotEmpty)
        _compactDropdown(
          label: 'Meter',
          icon: Icons.speed_rounded,
          value: (_selectedMeter != null && _meterNames.contains(_selectedMeter))
              ? _selectedMeter!
              : 'All Meters',
          items: ['All Meters', ..._meterNames],
          onChanged: (v) => setState(() {
            _selectedMeter = (v == 'All Meters') ? null : v;
          }),
          flex: 2,
        ),
      Expanded(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: MonthFilterDropdown(
              controller: widget.monthFilter,
              availableMonths: _monthKeys,
            ),
          ),
        ),
      ),
      IconButton.outlined(
        tooltip: 'Export PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
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
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 560;
        Widget row(List<Widget> items) => Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  items[i],
                ],
              ],
            );
        if (tight) {
          return AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                row([...children.take(children.length - 1).take(2)]),
                const SizedBox(height: 8),
                row([...children.skip(2)]),
              ],
            ),
          );
        }
        return AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: row(children),
        );
      },
    );
  }

  // ── Bill breakdown (Issue 5 — was only on Dashboard) ──────────────────
  static const _zoneTime = {
    'A': '00–06',
    'B': '06–09',
    'C': '09–17',
    'D': '17–24',
  };

  Widget _buildBillAnalysis() {
    final breakdown = BillCalculator.calculate(
      logs: _filtered,
      ratchetLogs: _entities,
    );
    if (breakdown.totalUnits <= 0) return const SizedBox.shrink();
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dim = _dimText;
    Color zoneCol(double amt) =>
        amt < 0 ? AppColors.success : amt > 0 ? AppColors.kpiEnergy : dim;
    final rows = <(String, double, Color)>[
      ('Energy Charges', breakdown.energyCharges, AppColors.kpiEnergy),
      ('Demand Charges', breakdown.demandCharges, AppColors.kpiDemand),
      for (final z in const ['A', 'B', 'C', 'D'])
        if ((breakdown.todZoneCharges[z] ?? 0) != 0)
          ('ToD $z (${_zoneTime[z]})', breakdown.todZoneCharges[z]!, zoneCol(breakdown.todZoneCharges[z]!)),
      ('Net ToD (slot engine)', breakdown.todCharges,
          breakdown.todCharges <= 0 ? AppColors.success : AppColors.danger),
      ('FAC', breakdown.facCharges, dim),
      ('Wheeling', breakdown.wheelingCharges, dim),
      ('Electricity Duty', breakdown.electricityDuty, dim),
      ('Taxes', breakdown.taxes, dim),
      if (breakdown.fixedCharge > 0)
        ('Fixed Charge', breakdown.fixedCharge, dim),
      ('PF Rebate', -breakdown.pfRebate, AppColors.kpiSavings),
      ('PF Surcharge', breakdown.pfSurcharge, AppColors.danger),
      ('Subsidy', -breakdown.subsidy, AppColors.kpiSavings),
      if (breakdown.rebateSection106 > 0)
        ('Rebate u/s 106', -breakdown.rebateSection106, AppColors.kpiSavings),
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
        ('Rounding', breakdown.roundingAdjustment, dim),
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
            '${_filtered.length} reading(s) — detailed breakdown incl. slot-wise ToD',
            style: TextStyle(fontSize: 12, color: dim),
          ),
          const Divider(height: 24),
          for (final (label, amount, color) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${amount < 0 ? '−' : ''}${currencyFmt.format(amount.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (label, amount) in [
                ('Pay early (PPD ${AppConfig.ppdPercent.toStringAsFixed(0)}%)', breakdown.payableEarly),
                ('Due', breakdown.netBill),
                ('After DPC', breakdown.payableAfterDpc),
              ]) ...[
                if (label != 'Due') const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? AppColors.surface2Dark
                          : AppColors.surface2Light,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 10.5, color: dim),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${amount.round()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Total Units: ${breakdown.totalUnits.toStringAsFixed(0)} ${AppConfig.billOnKvah ? 'kVAh' : 'kWh'}'
            '  ·  Billing Demand: ${breakdown.billingDemand.toStringAsFixed(1)} kVA'
            '  ·  Avg Unit Cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}'
            '  ·  PF: ${(breakdown.powerFactor * 100).toStringAsFixed(1)}%'
            '  ·  LF: ${(breakdown.loadFactor * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11, color: dim),
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
            style: TextStyle(fontSize: 12, color: AppColors.dim(context)),
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
        ? AppColors.dim(context)
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
                    color: _dimText,
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
  Widget _buildSystemIssues() {
    if (_filtered.isEmpty) return const SizedBox.shrink();
    final breakdown = BillCalculator.calculate(
      logs: _filtered,
      ratchetLogs: _entities,
    );
    if (breakdown.totalUnits <= 0) return const SizedBox.shrink();

    final issues =
        <({String title, String what, String how, int sev, double impact})>[];
    final cd = breakdown.contractDemand;
    final bd = breakdown.billingDemand;
    final pf = breakdown.powerFactor;
    final lf = breakdown.loadFactor;
    final tot = breakdown.totalUnits;
    final c = breakdown.todZoneCharges['C'] ?? 0;
    final d = breakdown.todZoneCharges['D'] ?? 0;
    final dUnits = breakdown.todZoneUnits['D'] ?? 0;
    final dc = AppConfig.demandChargePerKva;

    if (cd > 0 && bd >= cd) {
      issues.add((
        title: 'MD ceiling breach',
        what: 'Billed demand ${bd.round()} kVA ≥ contract demand ${cd.round()} kVA — '
            'excess-demand charge lagne laga hai.',
        how: 'Peak demand 10% shave karo: heavy loads 6–10 PM se hatao, critical '
            'loads backup/diesel pe le jao, warna CD badhwao.',
        sev: 3,
        impact: (bd - cd) * dc,
      ));
    } else if (cd > 0 && bd >= cd * 0.95) {
      issues.add((
        title: 'MD breach risk',
        what: 'Billed demand ${bd.round()} kVA CD ke 95% (${(cd * 0.95).round()} kVA) '
            'ke andar hai — ek hi spike breach kar sakta hai.',
        how: 'Peaking loads ko non-peak hours me shift karo; peak shaving/'
            'scheduling se next month MD breach mat hone do.',
        sev: 2,
        impact: cd * dc * 0.05,
      ));
    }
    if (tot > 0 && dUnits / tot >= 0.25) {
      issues.add((
        title: 'Peak-hour (D zone) overuse',
        what: '${(dUnits / tot * 100).toStringAsFixed(0)}% units D zone (17–24) me — '
            'peak surcharge ₹${d.round()} us par.',
        how: 'Heavy loads ko day me le aao (C zone solar rebate ₹${c.round()}). '
            'D se C shift = har unit par surcharge se rebate tak.',
        sev: 2,
        impact: d,
      ));
    }
    if (pf > 0 && pf < AppConstants.pfSurchargeThreshold) {
      issues.add((
        title: 'Power factor penalty',
        what: 'PF ${(pf * 100).toStringAsFixed(1)}% < 90% — penalty ${breakdown.pfSurcharge.round()} '
            'aur kVAh basis pe units bhi badhe.',
        how: 'Capacitor bank / APFC install karo. PF ≥ 0.95 target rakho — '
            'rebate milti hai (energy + demand ka 1%).',
        sev: 3,
        impact: breakdown.pfSurcharge,
      ));
    } else if (pf >= AppConstants.pfSurchargeThreshold &&
        pf < AppConstants.pfRebateThreshold) {
      issues.add((
        title: 'PF rebate miss',
        what: 'PF ${(pf * 100).toStringAsFixed(1)}% 90–95% ke beech — penalty nahi, '
            'lekin rebate bhi nahi mil rahi.',
        how: 'Thoda capacitor compensation badhao → PF ≥ 0.95 karo, rebate '
            'energy+demand ka 1% milne lagega.',
        sev: 1,
        impact: (breakdown.energyCharges + breakdown.demandCharges) * 0.01,
      ));
    }
    if (lf > 0 && lf < AppConstants.loadFactorThresholdGood) {
      issues.add((
        title: 'Low load factor',
        what: 'LF ${(lf * 100).toStringAsFixed(1)}% — demand charge har unit pe '
            'zyada pad raha hai (avg cost ₹${breakdown.averageUnitCost.toStringAsFixed(2)}/u).',
        how: 'Load smoothing karo: schedule 24×7 spread, ek saath chalu hone '
            'wale bade motors stagger karo.',
        sev: 2,
        impact: 0,
      ));
    }
    if (cd > 0 &&
        bd <= (cd * AppConstants.billingDemandFloorPercent).roundToDouble() &&
        cd * AppConstants.billingDemandFloorPercent > 0) {
      issues.add((
        title: 'Demand floor trap',
        what: 'Billed demand ${bd.round()} kVA CD ke 75% floor pe ghusa hai — '
            'poora CD ₹${(cd * dc).round()}/month demand me de rahe ho.',
        how: '12 mahine peak CD × 75% se neeche rahe to CD kam karwane ka review '
            'karo — saving ₹${((cd - bd) * dc).round()}/month.',
        sev: 1,
        impact: (cd - bd) * dc,
      ));
    }
    if (_meterKwhTargets.isNotEmpty) {
      final dailyTarget = _meterKwhTargets.values.fold(0.0, (a, b) => a + b);
      final days = (DateTime.now().difference(_filtered.first.loggedAt).inDays)
          .clamp(1, 31);
      final avgDaily = tot / days;
      if (avgDaily > dailyTarget * 1.05) {
        issues.add((
          title: 'Over-target consumption',
          what: 'Avg ${avgDaily.round()} kWh/day apne ${dailyTarget.round()} '
              'kWh/day target se 5%+ upar hai.',
          how: 'Non-essential loads off karo, peak window me consumption band '
              'karo, target ke andar aao.',
          sev: 1,
          impact: (avgDaily - dailyTarget) * AppConfig.tariffPerUnit * days,
        ));
      }
    }

    issues.sort((a, b) {
      final s = b.sev.compareTo(a.sev);
      return s != 0 ? s : b.impact.compareTo(a.impact);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'System Issues',
          subtitle:
              'kya galat hai + kaise theek karein — priority order (P1 sabse pehle)',
        ),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          AppCard(
            color:
                AppColors.success.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'System theek hai — koi critical issue nahi',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          for (final (i, a) in issues.indexed) ...[
            _issueCard(a, i),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _issueCard(
    ({String title, String what, String how, int sev, double impact}) a,
    int index,
  ) {
    final color = switch (a.sev) {
      3 => AppColors.danger,
      2 => AppColors.warning,
      _ => AppColors.info,
    };
    return AppCard(
      color: color.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                a.sev >= 3
                    ? Icons.error_rounded
                    : a.sev == 2
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'P${a.sev}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            a.what,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: _dimText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.build_circle_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.how,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: _isDark
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (a.impact > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Impact (approx): ₹${a.impact.round()}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
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
                    FlLine(color: _line, strokeWidth: 1),
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
                          style: TextStyle(
                            fontSize: 9,
                            color: _dimText,
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
                              color: AppColors.textOnDark,
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
                      style: TextStyle(
                        fontSize: 10,
                        color: _dimText,
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
style: TextStyle(
                      fontSize: 10,
                      color: _dimText,
                    ),
              ),
            ],
          ),
        ],
      ],
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
