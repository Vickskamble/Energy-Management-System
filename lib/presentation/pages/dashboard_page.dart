import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_kpi_card.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/month_filter_bar.dart';
import '../../core/calculation/bill_breakdown.dart';
import '../../core/calculation/bill_calculator.dart';
import '../../core/calculation/bill_forecast.dart';
import '../../core/calculation/savings_opportunity.dart';
import '../../core/insights/insight_generator.dart';
import '../../core/recommendations/recommendation_engine.dart';
import '../../data/repositories/meter_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';
import '../widgets/dashboard_chart.dart';
import '../widgets/monthly_consumption_chart.dart';
import '../widgets/readings_preview_sheet.dart';

typedef MeterAlert = ({
  String meterName,
  String? site,
  double pf,
  double md,
  double contract,
  List<({String issue, String solution})> items,
});

class DashboardPage extends StatefulWidget {
  /// Only refresh automatically while this tab is visible.
  final bool isActive;

  /// Shared month filter — Dashboard, Analysis & Reports stay in sync.
  final MonthFilterController monthFilter;

  /// Called when the user taps the first-run "Add your first meter" CTA so the
  /// shell can switch to the Meter Management tab.
  final VoidCallback? onNavigateToMeters;

  const DashboardPage({
    super.key,
    this.isActive = true,
    required this.monthFilter,
    this.onNavigateToMeters,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _refreshTimer;
  Map<String, String> _meterSites = {};

  @override
  void initState() {
    super.initState();
    _loadMeterSites();
    if (widget.isActive) _startAutoRefresh();
  }

  Future<void> _loadMeterSites() async {
    try {
      final meters = await context.read<MeterRepository>().getAllMeters();
      if (!mounted) return;
      setState(
        () => _meterSites = {for (final m in meters) m.name: m.site},
      );
    } catch (_) {
      // Best-effort; alert attribution falls back to meter name only.
    }
  }

  /// Meter with the lowest ΣkWh/ΣkVAh across the current data — the one most
  /// responsible for any PF penalty.
  ({String meterName, double pf})? _worstPfMeter(List<EnergyLogEntity> logs) {
    final sums = <String, ({double kwh, double kvah})>{};
    for (final e in logs) {
      final cur = sums[e.meterName] ?? (kwh: 0.0, kvah: 0.0);
      sums[e.meterName] = (
        kwh: cur.kwh + e.kwh * e.multiplyingFactor,
        kvah: cur.kvah + e.kvah * e.multiplyingFactor,
      );
    }
    ({String meterName, double pf})? worst;
    for (final entry in sums.entries) {
      final kvah = entry.value.kvah;
      final pf = kvah > 0 ? (entry.value.kwh / kvah).clamp(0.0, 1.0) : 0.0;
      if (worst == null || pf < worst.pf) {
        worst = (meterName: entry.key, pf: pf);
      }
    }
    return worst;
  }

  /// Meter with the highest actual MD (kVA) — the one at risk of an MD breach.
  ({String meterName, double md, double contract})? _worstMdMeter(
    List<EnergyLogEntity> logs,
  ) {
    ({String meterName, double md, double contract})? worst;
    for (final e in logs) {
      final md = e.mdRecorded * e.multiplyingFactor;
      if (worst == null || md > worst.md) {
        worst = (meterName: e.meterName, md: md, contract: e.contractDemand);
      }
    }
    return worst;
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyBloc, EnergyState>(
      listener: (context, state) {
        if (state is EnergySuccess) {
          final logs = state.logs.cast<EnergyLogEntity>();
          final worstPf = _worstPfMeter(logs);
          if (worstPf != null &&
              worstPf.pf < AppConstants.pfPenaltyThreshold) {
            NotificationService.instance.showPfAlert(
              worstPf.pf,
              meterName: worstPf.meterName,
              site: _meterSites[worstPf.meterName],
            );
          }
          final worstMd = _worstMdMeter(logs);
          if (worstMd != null &&
              worstMd.md >= worstMd.contract * 0.95) {
            NotificationService.instance.showMdAlert(
              worstMd.md,
              worstMd.contract,
              meterName: worstMd.meterName,
              site: _meterSites[worstMd.meterName],
            );
          }
        }
      },
      child: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          return switch (state) {
            EnergyInitial() || EnergyLoading() => const AppLoadingIndicator(
              message: 'Loading dashboard...',
            ),
            EnergySuccess(:final logs) => _DashboardContent(
              logs: logs,
              monthFilter: widget.monthFilter,
              onNavigateToMeters: widget.onNavigateToMeters,
            ),
            EnergyValidationError e => AppErrorState(
              message: e.message,
              onRetry: () => context.read<EnergyBloc>().add(
                const LoadInitialDashboardData(),
              ),
            ),
            EnergyOperationFailure e => AppErrorState(
              message: e.message,
              onRetry: () => context.read<EnergyBloc>().add(
                const LoadInitialDashboardData(),
              ),
            ),
          };
        },
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final List<dynamic> logs;
  final MonthFilterController monthFilter;
  final VoidCallback? onNavigateToMeters;

  const _DashboardContent({
    required this.logs,
    required this.monthFilter,
    this.onNavigateToMeters,
  });

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  String? _site;
  String? _meter;
  DateTime? _selectedDate;
  Map<String, String> _meterSites = {};

  /// Meter name → client's daily avg kWh consumption target (absent = unset).
  Map<String, double> _meterKwhTargets = {};

  /// Whether the user has configured at least one meter — drives the first-run CTA.
  bool _hasMeters = true;

  /// Cached, derived results so the heavy billing/savings/alert math runs only
  /// when the inputs (logs / filters) change — not on every rebuild.
  BillBreakdown? _breakdown;
  BusinessKpi? _kpis;
  MonthComparison? _comparison;
  BillForecast? _forecast;
  List<SavingOpportunity> _opportunities = const [];
  List<InsightItem> _insights = const [];
  List<RecommendationItem> _recommendations = const [];
  List<MeterAlert> _meterAlerts = const [];

  MonthFilterValue get _selection => widget.monthFilter.value;

  @override
  void initState() {
    super.initState();
    _loadMeterPresence();
    _loadMeterSites();
    context.read<MeterRepository>().addListener(_loadMeterSites);
    widget.monthFilter.addListener(_onFilterChanged);
    _recompute();
  }

  Future<void> _loadMeterPresence() async {
    try {
      final meters = await context.read<MeterRepository>().getAllMeters();
      if (mounted) setState(() => _hasMeters = meters.isNotEmpty);
    } catch (_) {
      // Best-effort; default to true so we don't wrongly show the first-run CTA.
    }
  }

  @override
  void didUpdateWidget(covariant _DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthFilter != widget.monthFilter) {
      oldWidget.monthFilter.removeListener(_onFilterChanged);
      widget.monthFilter.addListener(_onFilterChanged);
    }
    // New data arrived — derived results are now stale.
    if (oldWidget.logs != widget.logs) _recompute();
  }

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_loadMeterSites);
    widget.monthFilter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(_recompute);
  }

  /// Single place that runs every expensive derivation (bill, KPIs, comparison,
  /// forecast, savings opportunities, insights, recommendations, per-meter
  /// alerts). Called only when inputs change, never from build().
  void _recompute() {
    final entityLogs = _siteLogs;
    final periodLogs = _selectedLogs;
    final dayMode = _isDayMode;
    final breakdown = BillCalculator.calculate(
      logs: periodLogs,
      ratchetLogs: entityLogs,
      demandRate: dayMode ? 0 : null,
    );
    final kpis = BillCalculator.calculateKpis(breakdown);
    final now = DateTime.now();
    final isCurrentMonth = _selection.isCurrent;
    final refMonth = isCurrentMonth ||
            _selection.year != null ||
            _selection.allTime
        ? null
        : DateTime(_selection.month!.year, _selection.month!.month);
    final previousMonth = refMonth == null
        ? DateTime(now.year, now.month - 1, 1)
        : DateTime(refMonth.year, refMonth.month - 1, 1);
    final previousLogs = dayMode
        ? entityLogs
            .where(
              (l) => _isSameDay(
                l.loggedAt,
                _selectedDate!.subtract(const Duration(days: 1)),
              ),
            )
            .toList()
        : entityLogs
            .where(
              (l) =>
                  l.loggedAt.year == previousMonth.year &&
                  l.loggedAt.month == previousMonth.month,
            )
            .toList();
    final previousBreakdown = previousLogs.isEmpty
        ? null
        : BillCalculator.calculate(
            logs: previousLogs,
            ratchetLogs: entityLogs,
            demandRate: dayMode ? 0 : null,
          );
    final comparison = periodLogs.isEmpty
        ? null
        : BillCalculator.compare(breakdown, previousBreakdown);
    // Forecast is meaningful only for the live (current) month.
    final forecast = !dayMode && isCurrentMonth
        ? BillForecastCalculator.calculate(
            monthLogs: periodLogs,
            referenceDate: now,
            ratchetLogs: entityLogs,
          )
        : null;
    // Saving opportunities are ₹/month figures — always computed from the
    // month's data, even in Daily mode.
    final opportunities = SavingOpportunityGenerator.generate(
      dayMode
          ? BillCalculator.calculate(
              logs: _selectedMonthLogs,
              ratchetLogs: entityLogs,
            )
          : breakdown,
    );
    final contractOptimizer =
        SavingOpportunityGenerator.generateContractDemandOptimizer(
          logs: entityLogs,
          contractDemand: breakdown.contractDemand,
        );
    if (contractOptimizer != null) {
      opportunities.add(contractOptimizer);
      opportunities.sort(
        (a, b) => b.monthlySavings.compareTo(a.monthlySavings),
      );
    }
    final insights = InsightGenerator.generate(
      breakdown: breakdown,
      comparison: comparison,
      kpis: kpis,
      logs: periodLogs,
    );
    final recommendations = RecommendationEngine.generate(
      breakdown: breakdown,
      comparison: null,
      logs: periodLogs,
    );

    _breakdown = breakdown;
    _kpis = kpis;
    _comparison = comparison;
    _forecast = forecast;
    _opportunities = opportunities;
    _insights = insights;
    _recommendations = recommendations;
    _meterAlerts = _allMeterAlerts;
  }

  Future<void> _loadMeterSites() async {
    try {
      final meters = await context.read<MeterRepository>().getAllMeters();
      if (!mounted) return;
      setState(() {
        _meterSites = {for (final m in meters) m.name: m.site};
        _meterKwhTargets = {
          for (final m in meters)
            if (m.dailyKwhTarget > 0) m.name: m.dailyKwhTarget,
        };
      });
      _recompute();
    } catch (_) {
      // Best-effort — dashboard still renders without site filter.
    }
  }

  List<String> get _siteNames {
    final names = _meterSites.values.toSet().toList()..sort();
    return names;
  }

  /// Logs filtered by the selected site (Issue 7E), then by the selected
  /// meter when one is chosen — every KPI, chart and comparison downstream
  /// reads per-meter data instead of a combined total.
  List<EnergyLogEntity> get _siteLogs {
    var logs = widget.logs.cast<EnergyLogEntity>();
    if (_site != null) {
      final meterNames = <String>{
        for (final e in _meterSites.entries)
          if (e.value == _site) e.key,
      };
      if (meterNames.isEmpty) return const [];
      logs = logs.where((e) => meterNames.contains(e.meterName)).toList();
    }
    final meter = _meter;
    if (meter != null) {
      logs = logs.where((e) => e.meterName == meter).toList();
    }
    return logs;
  }

  /// Meters for the chips row: every meter added in the app (Meter table)
  /// plus any distinct meter still present in historical log data, so the
  /// selector is visible even when only one meter exists.
  List<String> get _meterNames {    final names = <String>{
      for (final name in _meterSites.keys) name,
      for (final l in widget.logs.cast<EnergyLogEntity>()) l.meterName,
    }.toList()
      ..sort();
    return names;
  }

  /// Logs belonging to the selected month (or current month by default).
  List<EnergyLogEntity> get _selectedMonthLogs =>
      _siteLogs.where((l) => _selection.matches(l.loggedAt)).toList();

  bool get _isDayMode => _selectedDate != null;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Logs for the selected day when Daily mode is on, otherwise the selected
  /// month — every KPI card reads from here, so the whole dashboard follows
  /// the date-wise selection.
  List<EnergyLogEntity> get _selectedLogs {
    final d = _selectedDate;
    if (d != null) {
      return _siteLogs.where((l) => _isSameDay(l.loggedAt, d)).toList();
    }
    return _selectedMonthLogs;
  }

  /// Logs feeding the Monthly Consumption chart. Same site/meter scope as the
  /// rest of the dashboard, aligned with the selection:
  ///  - a specific month picked → ONLY that month's logs, so the chart shows
  ///    exactly the same value as the Total Consumption KPI;
  ///  - a year / current / all-time → that year's monthly trend.
  List<EnergyLogEntity> get _consumptionChartLogs {
    final logs = _siteLogs;
    if (logs.isEmpty) return logs;
    final m = _selection.month;
    if (m != null) {
      return logs
          .where(
            (l) => l.loggedAt.year == m.year && l.loggedAt.month == m.month,
          )
          .toList();
    }
    final int year;
    if (_selection.year != null) {
      year = _selection.year!;
    } else if (_selection.isCurrent) {
      year = DateTime.now().year;
    } else {
      return logs; // all-time → let the chart use its latest year
    }
    return logs.where((l) => l.loggedAt.year == year).toList();
  }

  DateTime? get _earliestLogDate {
    if (_siteLogs.isEmpty) return null;
    final sorted = _siteLogs.map((l) => l.loggedAt).toList()..sort();
    return sorted.first;
  }

  /// Latest year present in [logs] — the year the monthly charts plot.
  int _maxYearOf(List<EnergyLogEntity> logs) {
    if (logs.isEmpty) return DateTime.now().year;
    return logs
        .map((l) => l.loggedAt.year)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Daily avg kWh budget for the visible scope — a single meter uses its own
  /// target, all meters sum their targets (the site budget line). Based on
  /// registered meters only, so the line shows even before readings exist.
  double get _dailyKwhTarget {
    if (_meterKwhTargets.isEmpty) return 0;
    if (_meter != null) return _meterKwhTargets[_meter] ?? 0;
    if (_site != null) {
      final siteMeters = {
        for (final e in _meterSites.entries)
          if (e.value == _site) e.key,
      };
      var total = 0.0;
      for (final entry in _meterKwhTargets.entries) {
        if (siteMeters.contains(entry.key)) total += entry.value;
      }
      return total;
    }
    return _meterKwhTargets.values.fold(0.0, (a, b) => a + b);
  }

  /// Opens the readings preview sheet for a tapped chart month.
  void _showMonthReadings(List<EnergyLogEntity> source, int month) {
    final year = _maxYearOf(source);
    final logs =
        source
            .where(
              (l) => l.loggedAt.year == year && l.loggedAt.month == month,
            )
            .toList();
    showReadingsPreviewSheet(
      context,
      title: '${DateFormat('MMM yyyy').format(DateTime(year, month))} — '
          'Readings',
      logs: logs,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = _earliestLogDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? (first.isAfter(now) ? now : first),
      firstDate: first.isAfter(now) ? now : first,
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _recompute();
      });
    }
  }

  /// "July 2026 — " or "12 Aug 2026 — " prefix on KPI cards when a
  /// non-current period is viewed.
  String get _kpiMonthLabel {
    final d = _selectedDate;
    if (d != null) return '${DateFormat('d MMM yyyy').format(d)} — ';
    if (_selection.isCurrent) return '';
    return '${_selection.label} — ';
  }

  /// Distinct months present in the (site-filtered) data, for the filter bar.
  /// The current month is always included so the dropdown keeps working even
  /// when no readings exist yet.
  List<DateTime> get _availableMonths {
    final now = DateTime.now();
    final keys = <String, DateTime>{
      '${now.year}-${now.month}': DateTime(now.year, now.month),
    };
    for (final l in _siteLogs) {
      keys['${l.loggedAt.year}-${l.loggedAt.month}'] = DateTime(
        l.loggedAt.year,
        l.loggedAt.month,
      );
    }
    final list = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Site-aware KPI values — full-data values when "All Sites".
  /// In Daily mode the estimated bill excludes the monthly demand charge,
  /// so the card reflects the day's actual usage cost.
  double get _siteEstimatedBill => _breakdown?.netBill ?? 0;

  double get _siteTotalConsumption {
    return _selectedLogs.fold(
      0.0,
      (s, e) => s + e.kwh * e.multiplyingFactor,
    );
  }

  double get _siteMaxDemandPeak {
    return _selectedLogs.fold(
      0.0,
      (s, e) => e.mdRecorded * e.multiplyingFactor > s
          ? e.mdRecorded * e.multiplyingFactor
          : s,
    );
  }

  double get _sitePowerFactor => _breakdown?.powerFactor ?? 0;

  /// Visible formula for the Power Factor card: per-meter and combined PF as
  /// ΣkWh ÷ ΣkVAh (ratio of sums) — the utility's billing method.
  String get _powerFactorBreakdown {
    if (_selectedLogs.isEmpty) return 'No readings — add kVAh data';
    final perMeter = <String, ({double kwh, double kvah})>{};
    var sumKwh = 0.0;
    var sumKvah = 0.0;
    for (final l in _selectedLogs) {
      final kwh = l.kwh * l.multiplyingFactor;
      final kvah = l.kvah * l.multiplyingFactor;
      final rec = perMeter.putIfAbsent(
        l.meterName,
        () => (kwh: 0, kvah: 0),
      );
      perMeter[l.meterName] = (
        kwh: rec.kwh + kwh,
        kvah: rec.kvah + kvah,
      );
      sumKwh += kwh;
      sumKvah += kvah;
    }
    final nf = NumberFormat.decimalPattern('en_IN');
    final combined = sumKvah > 0 ? (sumKwh / sumKvah).toStringAsFixed(3) : '—';
    final lines = <String>[
      'As recorded (kWh ÷ kVAh): $combined',
    ];
    for (final e in perMeter.entries) {
      final d = e.value;
      final pf =
          d.kvah > 0 ? 'PF ${(d.kwh / d.kvah).toStringAsFixed(3)}' : 'PF —';
      lines.add('${e.key}: ${nf.format(d.kwh)} kWh · $pf');
    }
    return lines.join('\n');
  }

  /// Today's usage (current month), the selected month's daily average, or
  /// the selected day's total in Daily mode.
  double get _todayUnits {
    if (_isDayMode) {
      return _selectedLogs.fold(
        0.0,
        (s, l) => s + l.kwh * l.multiplyingFactor,
      );
    }
    if (_selection.isCurrent) {
      final now = DateTime.now();
      final todays = _siteLogs
          .where(
            (l) =>
                l.loggedAt.year == now.year &&
                l.loggedAt.month == now.month &&
                l.loggedAt.day == now.day,
          )
          .toList();
      if (todays.isNotEmpty) {
        return todays.fold(0.0, (s, l) => s + l.kwh * l.multiplyingFactor);
      }
      if (_siteLogs.isEmpty) return 0.0;
      final last = _siteLogs.last;
      return last.kwh * last.multiplyingFactor;
    }
    final monthLogs = _selectedMonthLogs;
    if (monthLogs.isEmpty) return 0.0;
    final total = monthLogs.fold(
      0.0,
      (s, l) => s + l.kwh * l.multiplyingFactor,
    );
    final year = _selection.year;
    final days = year != null
        ? 365
        : (_selection.allTime
              ? _siteLogs.length.clamp(1, 365)
              : DateTime(
                  _selection.month!.year,
                  _selection.month!.month + 1,
                  0,
                ).day);
    return (total / days * 100).roundToDouble() / 100;
  }

  /// Distinct years present in the (site-filtered) data, for the filter bar.
  /// The current year is always included so the dropdown keeps working even
  /// when no readings exist yet.
  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final l in _siteLogs) {
      years.add(l.loggedAt.year);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Days present in the selected month, for the Daily dropdown.
  List<DateTime> get _availableDays {
    final keys = <String, DateTime>{};
    for (final l in _selectedMonthLogs) {
      keys['${l.loggedAt.year}-${l.loggedAt.month}-${l.loggedAt.day}'] =
          DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day);
    }
    final list = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        value: value,
        icon: Icon(icon, size: 18, color: AppColors.primary),
        hint: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        dropdownColor: scheme.surface,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  /// Compact single-row filter bar: Site, Meter, Year, Month, Daily — every
  /// control is a dropdown so the dashboard no longer scrolls vertically just
  /// to change a filter.
  Widget _buildDropdownFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Site
          if (_siteNames.isNotEmpty) ...[
            _filterDropdown<String>(
              label: 'All Sites',
              icon: Icons.location_on_outlined,
              value: (_site != null && _siteNames.contains(_site))
                  ? _site!
                  : 'all',
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Sites')),
                for (final s in _siteNames)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _site = (v == 'all') ? null : v;
                _recompute();
              }),
            ),
          ] else
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isDense: true,
                value: 'all',
                hint: const Text('No site'),
                items: const [DropdownMenuItem(value: 'all', child: Text('No site'))],
                onChanged: (_) {},
              ),
            ),
          const SizedBox(width: 12),
          // Meter
          _filterDropdown<String>(
            label: 'All Meters',
            icon: Icons.speed_rounded,
            value: (_meter != null && _meterNames.contains(_meter))
                ? _meter!
                : 'all',
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Meters')),
              for (final m in _meterNames)
                DropdownMenuItem(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _meter = (v == 'all') ? null : v;
              _recompute();
            }),
          ),
          const SizedBox(width: 12),
          // Year
          _filterDropdown<String>(
            label: 'All Years',
            icon: Icons.date_range,
            value: _selection.year?.toString() ?? 'all',
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Years')),
              if (_selection.year != null &&
                  !_availableYears.contains(_selection.year))
                DropdownMenuItem(
                  value: '${_selection.year}',
                  child: Text('${_selection.year}'),
                ),
              for (final y in _availableYears)
                DropdownMenuItem(value: '$y', child: Text('$y')),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == 'all') {
                widget.monthFilter.value = const MonthFilterValue.allTime();
              } else {
                widget.monthFilter.value = MonthFilterValue.year(int.parse(v));
              }
            },
          ),
          const SizedBox(width: 12),
          // Month
          _filterDropdown<String>(
            label: 'This Month',
            icon: Icons.calendar_month,
            value: _selection.month != null &&
                    _availableMonths.any(
                      (m) =>
                          m.year == _selection.month!.year &&
                          m.month == _selection.month!.month,
                    )
                ? '${_selection.month!.year}-${_selection.month!.month}'
                : 'current',
            items: [
              const DropdownMenuItem(
                value: 'current',
                child: Text('This Month'),
              ),
              for (final m in _availableMonths)
                DropdownMenuItem(
                  value: '${m.year}-${m.month}',
                  child: Text(DateFormat('MMM yy').format(m)),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == 'current') {
                widget.monthFilter.value = const MonthFilterValue.current();
                return;
              }
              final parts = v.split('-');
              widget.monthFilter.value = MonthFilterValue.month(
                DateTime(int.parse(parts[0]), int.parse(parts[1])),
              );
            },
          ),
          const SizedBox(width: 12),
          // Daily
          _filterDropdown<String>(
            label: 'Monthly',
            icon: _isDayMode ? Icons.today : Icons.calendar_month,
            value: _selectedDate == null
                ? 'monthly'
                : _availableDays.any(
                        (d) =>
                            _isSameDay(d, _selectedDate!)) &&
                        _selectedLogs.isNotEmpty
                    ? '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}'
                    : 'pick',
            items: [
              const DropdownMenuItem(
                value: 'monthly',
                child: Text('Monthly'),
              ),
              for (final d in _availableDays)
                DropdownMenuItem(
                  value: '${d.year}-${d.month}-${d.day}',
                  child: Text(DateFormat('d MMM yy').format(d)),
                ),
              const DropdownMenuItem(
                value: 'pick',
                child: Text('Pick a date…'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == 'monthly') {
                setState(() {
                  _selectedDate = null;
                  _recompute();
                });
              } else if (v == 'pick') {
                _pickDate();
              } else {
                final p = v.split('-');
                setState(() {
                  _selectedDate = DateTime(
                    int.parse(p[0]),
                    int.parse(p[1]),
                    int.parse(p[2]),
                  );
                  _recompute();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entityLogs = _siteLogs;
    final periodLogs = _selectedLogs;
    final breakdown = _breakdown!;
    final kpis = _kpis!;
    final comparison = _comparison;
    final forecast = _forecast;
    final opportunities = _opportunities;
    final insights = _insights;
    final recommendations = _recommendations;
    final isCurrentMonth = _selection.isCurrent;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _buildDropdownFilterBar(),
          const SizedBox(height: AppSpacing.lg),
          _buildAllAlertsSection(context),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppSectionHeader(
                  title: 'Energy Overview',
                  subtitle: _kpiMonthLabel.isEmpty
                    ? 'Bill analysis and monitoring dashboard'
                    : '$_kpiMonthLabel bill analysis & monitoring',
                ),
              ),
              Tooltip(
                message: 'Refresh data',
                child: IconButton.filledTonal(
                  onPressed: () => context.read<EnergyBloc>().add(
                    const LoadInitialDashboardData(),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _scopeChip(
                Icons.location_on_rounded,
                'Site',
                _site ?? 'All Sites',
              ),
              _scopeChip(
                Icons.electrical_services_rounded,
                'Meter',
                _meter ?? 'All Meters',
              ),
            ],
          ),

          if (periodLogs.isEmpty && !_hasMeters && !_isDayMode) ...[
            AppEmptyState(
              icon: Icons.bolt_rounded,
              title: 'Welcome to PowerEMS',
              subtitle:
                  'Add your first meter to start tracking energy usage and bills.',
              actionLabel: 'Add your first meter',
              onAction: widget.onNavigateToMeters,
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else if (periodLogs.isEmpty) ...[
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        size: 40,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isDayMode
                            ? 'No readings on ${DateFormat('d MMM yyyy').format(_selectedDate!)}'
                            : isCurrentMonth
                            ? 'No readings yet this month'
                            : 'No readings in ${_selection.label}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isDayMode
                            ? 'Pick another date or add readings in Reading Entry'
                            : 'Select another month above or add readings in Reading Entry',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          _kpiGrid(
            cards: [
              AppKpiCard(
                title: _isDayMode ? 'Day Bill (est.)' : 'Est. Monthly Bill',
                value: _siteEstimatedBill,
                suffix: '₹',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.kpiCost,
                decimals: 0,
                description: _isDayMode
                    ? '${_kpiMonthLabel}Demand charge excluded — avg unit cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}'
                    : '${_kpiMonthLabel}Avg unit cost: ₹${breakdown.averageUnitCost.toStringAsFixed(2)}',
              ),
              AppKpiCard(
                title: _isDayMode ? 'Day Consumption' : 'Total Consumption',
                value: _siteTotalConsumption,
                suffix: 'kWh',
                icon: Icons.bolt_rounded,
                color: AppColors.kpiEnergy,
                decimals: 0,
                description:
                    '$_kpiMonthLabel${_siteTotalConsumption.toStringAsFixed(0)} kWh consumed',
              ),
              AppKpiCard(
                title: 'Max Demand',
                value: _siteMaxDemandPeak,
                suffix: 'kVA',
                icon: Icons.trending_up_rounded,
                color: _siteMaxDemandPeak >= AppConstants.mdWarningThresholdKva
                    ? AppColors.warning
                    : AppColors.kpiDemand,
                description:
                    '${_kpiMonthLabel}Billing demand: ${breakdown.billingDemand.toStringAsFixed(1)} kVA',
              ),
              AppKpiCard(
                title: 'Power Factor',
                value: _sitePowerFactor,
                suffix: 'PF',
                icon: Icons.waves_rounded,
                color: _sitePowerFactor <= 0
                    ? AppColors.textSecondary
                    : (_sitePowerFactor < AppConstants.pfPenaltyThreshold
                          ? AppColors.danger
                          : AppColors.kpiPower),
                decimals: 3,
                description: _sitePowerFactor <= 0
                    ? 'No kVAh data — enter kVAh in your readings'
                    : _powerFactorBreakdown,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _kpiGrid(
            cards: [
              AppKpiCard(
                title: 'Bill Health Score',
                value: kpis.billHealthScore,
                suffix: '/100',
                icon: Icons.health_and_safety_rounded,
                color: kpis.billHealthScore >= 80
                    ? AppColors.kpiEfficiency
                    : (kpis.billHealthScore >= 60
                          ? AppColors.warning
                          : AppColors.danger),
                decimals: 0,
                description: kpis.billHealthScore >= 80
                    ? 'Good — all parameters optimized'
                    : kpis.billHealthScore >= 60
                    ? 'Needs attention'
                    : 'Critical issues',
              ),
              AppKpiCard(
                title: 'Load Factor',
                value: breakdown.loadFactor * 100,
                suffix: '%',
                icon: Icons.speed_rounded,
                color:
                    breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
                    ? AppColors.kpiEfficiency
                    : AppColors.warning,
                decimals: 0,
                description:
                    breakdown.loadFactor >= AppConstants.loadFactorThresholdGood
                    ? 'Efficient usage'
                    : 'Improve load smoothing',
              ),
              AppKpiCard(
                title: _isDayMode
                    ? 'Readings'
                    : (_selection.isCurrent ? 'Latest Reading' : 'Daily Avg'),
                value: _isDayMode
                    ? _selectedLogs.length.toDouble()
                    : _todayUnits,
                suffix: _isDayMode ? 'entries' : 'units',
                icon: Icons.today_rounded,
                color: AppColors.kpiSavings,
                description: _isDayMode
                    ? 'Readings logged on ${DateFormat('d MMM yyyy').format(_selectedDate!)}'
                    : _selection.isCurrent
                    ? 'Last reading — consumption in units (kWh × MF)'
                    : '${_selection.label} average per day (kWh × MF)',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildMdBreachCard(periodLogs),
          const SizedBox(height: AppSpacing.lg),

          const SizedBox(height: AppSpacing.xxl),

          if (opportunities.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Bill Saving Opportunities',
              subtitle: 'Direct monthly savings — priority order me',
            ),
            if (MediaQuery.of(context).size.width < 600)
              Column(
                children: [
                  for (var i = 0; i < opportunities.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.lg),
                    _SavingOpportunityCard(opportunity: opportunities[i]),
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < opportunities.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _SavingOpportunityCard(
                        opportunity: opportunities[i],
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          AppSectionHeader(
            title: 'Trends',
            subtitle: 'Site / meter select kar ke trend aur consumption analyze karein',
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_siteNames.isNotEmpty) ...[
                  _filterDropdown<String>(
                    label: 'All Sites',
                    icon: Icons.location_on_outlined,
                    value: (_site != null && _siteNames.contains(_site))
                        ? _site!
                        : 'all',
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Sites'),
                      ),
                      for (final s in _siteNames)
                        DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _site = (v == 'all') ? null : v;
                      _recompute();
                    }),
                  ),
                  const SizedBox(width: 12),
                ],
                _filterDropdown<String>(
                  label: 'All Meters',
                  icon: Icons.speed_rounded,
                  value: (_meter != null && _meterNames.contains(_meter))
                      ? _meter!
                      : 'all',
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Meters'),
                    ),
                    for (final m in _meterNames)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _meter = (v == 'all') ? null : v;
                    _recompute();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (MediaQuery.of(context).size.width < 600)
            Column(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demand Trend (kVA)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: DashboardChart(
                          logs: entityLogs,
                          onMonthTap: (m) => _showMonthReadings(entityLogs, m),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Consumption',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: MonthlyConsumptionChart(
                          logs: _consumptionChartLogs,
                          targetKwhPerDay: _dailyKwhTarget,
                          onMonthTap: (m) =>
                              _showMonthReadings(_consumptionChartLogs, m),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demand Trend (kVA)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: DashboardChart(
                            logs: entityLogs,
                            onMonthTap: (m) => _showMonthReadings(entityLogs, m),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 2,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Consumption',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: MonthlyConsumptionChart(
                            logs: _consumptionChartLogs,
                            targetKwhPerDay: _dailyKwhTarget,
                            onMonthTap: (m) =>
                                _showMonthReadings(_consumptionChartLogs, m),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(
            title: 'Charts',
            subtitle: 'Comparison and forecast analysis',
          ),
          const SizedBox(height: AppSpacing.lg),

          if (MediaQuery.of(context).size.width < 600)
            Column(
              children: [
                _buildComparisonCard(comparison),
                const SizedBox(height: AppSpacing.lg),
                _buildForecastCard(forecast),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildComparisonCard(comparison)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildForecastCard(forecast)),
              ],
            ),
          const SizedBox(height: AppSpacing.xxl),

          if (insights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildInsightsSection(insights),
          ],
          const SizedBox(height: AppSpacing.xl),

          if (recommendations.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Recommendations',
              subtitle: 'Actionable steps to reduce your bill',
            ),
            ...recommendations
                .take(3)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecommendationCard(rec: r),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid({required List<Widget> cards}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = MediaQuery.of(context).size.width;
        final columns = width < 600 ? 2 : 4;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: cardWidth / 180,
          children: cards,
        );
      },
    );
  }

  Widget _buildMdBreachCard(List<EnergyLogEntity> logs) {
    final events = _mdEvents(logs);
    if (events.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Maximum Demand History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${events.length} event(s)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${events[i].loggedAt.day}/${events[i].loggedAt.month}/${events[i].loggedAt.year} '
                          '${events[i].loggedAt.hour.toString().padLeft(2, '0')}:${events[i].loggedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          events[i].meterName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(events[i].mdRecorded * events[i].multiplyingFactor).toStringAsFixed(1)} / '
                    '${events[i].contractDemand.toStringAsFixed(0)} kVA',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          events[i].mdRecorded * events[i].multiplyingFactor >=
                              events[i].contractDemand
                          ? AppColors.danger
                          : AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      events[i].mdRecorded * events[i].multiplyingFactor >=
                              events[i].contractDemand
                          ? 'BREACH'
                          : 'NEAR',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<EnergyLogEntity> _mdEvents(List<EnergyLogEntity> logs) {
    final sorted = List<EnergyLogEntity>.from(logs)
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return sorted
        .where(
          (l) =>
              l.mdRecorded * l.multiplyingFactor >=
              l.contractDemand * AppConstants.mdWarningRatio,
        )
        .take(5)
        .toList();
  }

  Widget _buildInsightsSection(List<InsightItem> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Smart Insights',
          subtitle: 'What these numbers mean for your business',
        ),
        ...insights
            .take(4)
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightCard(insight: i),
              ),
            ),
      ],
    );
  }

  Widget _buildComparisonCard(MonthComparison? comparison) {
    return AppCard(
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
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Comparison',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (comparison != null && comparison.isBillDecreased)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.savings_rounded,
                        size: 12,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Saved ₹${comparison.billDifference.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (comparison == null || comparison.current.netBill <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _isDayMode
                      ? 'No reading recorded for this day yet'
                      : 'No reading recorded for this month yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            _comparisonRow(
              label: 'Est. Bill',
              value: '₹${comparison.current.netBill.toStringAsFixed(0)}',
              chipText: comparison.previous == null
                  ? 'first ${_isDayMode ? 'day' : 'month'}'
                  : '${comparison.billDifference >= 0 ? '↑' : '↓'} ${comparison.billPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.billDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Consumption',
              value: '${comparison.current.totalUnits.toStringAsFixed(0)} kWh',
              chipText: comparison.previous == null
                  ? 'first ${_isDayMode ? 'day' : 'month'}'
                  : '${comparison.unitDifference >= 0 ? '↑' : '↓'} ${comparison.unitPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.unitDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Max Demand',
              value:
                  '${comparison.current.billingDemand.toStringAsFixed(1)} kVA',
              chipText: comparison.previous == null
                  ? 'first ${_isDayMode ? 'day' : 'month'}'
                  : '${comparison.demandDifference >= 0 ? '↑' : '↓'} ${comparison.demandPercentChange.abs().toStringAsFixed(1)}%',
              isGood: comparison.demandDifference <= 0,
              chipNeutral: comparison.previous == null,
            ),
            const Divider(height: 20),
            _comparisonRow(
              label: 'Power Factor',
              value: comparison.current.powerFactor.toStringAsFixed(3),
              chipText: comparison.previous == null
                  ? 'first ${_isDayMode ? 'day' : 'month'}'
                  : 'vs ${comparison.previous!.powerFactor.toStringAsFixed(3)}',
              isGood: comparison.pfDifference >= 0,
              chipNeutral: comparison.previous == null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonRow({
    required String label,
    required String value,
    required String chipText,
    required bool isGood,
    bool chipNeutral = false,
  }) {
    final chipColor = chipNeutral
        ? AppColors.textSecondary
        : (isGood ? AppColors.success : AppColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(BillForecast? forecast) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.kpiCost.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: AppColors.kpiCost,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Bill Forecast',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isDayMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Bill forecast is only available in Monthly mode — select "Monthly"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else if (forecast == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No reading recorded for this month yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              'Projected Month-End Bill',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${forecast.projectedBill.toStringAsFixed(0)}',
              style: AppTypography.mono(
                size: 28,
                weight: FontWeight.w700,
                color: AppColors.kpiCost,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '≈ ${forecast.projectedUnits.toStringAsFixed(0)} kWh units',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            Row(
              children: [
                _forecastStat(
                  'Avg / day',
                  '₹${forecast.dailyAverageBill.toStringAsFixed(0)}',
                ),
                _forecastStat(
                  'Days left',
                  '${forecast.daysInMonth - forecast.daysElapsed}',
                ),
                _forecastStat(
                  'Progress',
                  '${(forecast.daysElapsed / forecast.daysInMonth * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: forecast.daysElapsed / forecast.daysInMonth,
                minHeight: 6,
                color: AppColors.kpiCost,
                backgroundColor: AppColors.kpiCost.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
            'Estimated at today\'s usage rate — updates as readings are added',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _forecastStat(String label, String value) {
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }


  /// Alerts for EVERY added meter for the selected period, ignoring the
  /// site/meter filter — so the client always sees which specific meters
  /// (and their site) have a PF or MD issue, with a remedy, even when only
  /// one meter is selected.
  List<MeterAlert> get _allMeterAlerts {
    final periodLogs = widget.logs
        .cast<EnergyLogEntity>()
        .where((l) => _selection.matches(l.loggedAt))
        .toList();
    final byMeter = <String, List<EnergyLogEntity>>{};
    for (final e in periodLogs) {
      (byMeter[e.meterName] ??= []).add(e);
    }
    final alerts = <MeterAlert>[];
    for (final entry in byMeter.entries) {
      final logs = entry.value;
      var kwh = 0.0;
      var kvah = 0.0;
      var md = 0.0;
      var contract = 0.0;
      for (final e in logs) {
        kwh += e.kwh * e.multiplyingFactor;
        kvah += e.kvah * e.multiplyingFactor;
        final m = e.mdRecorded * e.multiplyingFactor;
        if (m > md) md = m;
        if (e.contractDemand > contract) contract = e.contractDemand;
      }
      final pf = kvah > 0 ? (kwh / kvah).clamp(0.0, 1.0) : 0.0;
      final items = <({String issue, String solution})>[];
      if (pf > 0 && pf < AppConstants.pfRebateThreshold) {
        final hasSurcharge = pf < AppConstants.pfSurchargeThreshold;
        final target = AppConstants.pfRebateThreshold;
        final goal = hasSurcharge
            ? 'Raise PF to ≥$target to remove the 5% surcharge and earn the 1% rebate'
            : 'Raise PF to ≥$target to earn the 1% rebate';
        items.add((
          issue: hasSurcharge
              ? 'Low PF (${pf.toStringAsFixed(3)}) — 5% reactive penalty + missing 1% rebate'
              : 'Low PF (${pf.toStringAsFixed(3)}) — missing the 1% PF rebate',
          solution: '$goal — check the APFC panel and its capacitor.',
        ));
      }
      if (contract > 0 && md >= contract * 0.95) {
        items.add((
          issue: 'MD near contract limit '
              '(${md.toStringAsFixed(1)} / $contract kVA)',
          solution:
              'Shift non-essential loads to off-peak hours — peak MD is ≥95% of contract and attracts an excess-demand penalty.',
        ));
      }
      // Daily avg kWh target (set on the meter) — alert near/cross.
      final target = _meterKwhTargets[entry.key] ?? 0.0;
      if (target > 0 && logs.isNotEmpty) {
        final latest = logs
            .map((e) => e.loggedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        var dayKwh = 0.0;
        for (final e in logs) {
          if (e.loggedAt.year == latest.year &&
              e.loggedAt.month == latest.month &&
              e.loggedAt.day == latest.day) {
            dayKwh += e.kwh * e.multiplyingFactor;
          }
        }
        if (dayKwh >= target) {
          items.add((
            issue: 'Daily consumption crossed target '
                '(${dayKwh.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} kWh)',
            solution:
                'Daily consumption exceeded the ${target.toStringAsFixed(0)} kWh/day budget — identify and shift the heavy loads to off-peak hours.',
          ));
        } else if (dayKwh >= target * AppConstants.dailyKwhWarningRatio) {
          items.add((
            issue: 'Daily consumption near target '
                '(${dayKwh.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} kWh)',
            solution:
                'Consumption is at ≥${(AppConstants.dailyKwhWarningRatio * 100).toStringAsFixed(0)}% of the ${target.toStringAsFixed(0)} kWh/day budget — avoid heavy loads for the rest of the day.',
          ));
        }
      }
      if (items.isNotEmpty) {
        alerts.add((
          meterName: entry.key,
          site: _meterSites[entry.key],
          pf: pf,
          md: md,
          contract: contract,
          items: items,
        ));
      }
    }
    alerts.sort((a, b) => a.meterName.compareTo(b.meterName));
    return alerts;
  }

  /// Small label chip used under "Energy Overview" to make it obvious which
  /// site and meter the visible data belongs to.
  Widget _scopeChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Single, unified Alerts section — shown for ALL sites & meters regardless
  /// of the site/meter filter, each with its issue and a remedy.
  Widget _buildAllAlertsSection(BuildContext context) {
    final alerts = _meterAlerts;
    final hasIssues = alerts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Alerts',
          subtitle: hasIssues
              ? 'All sites & meters — ${_selection.label}'
              : 'All meters normal — ${_selection.label}',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!hasIssues)
          AppCard(
            color: AppColors.success.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'All meters within normal limits for ${_selection.label}.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final a in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                color: AppColors.danger.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            a.site != null && a.site!.trim().isNotEmpty
                                ? '${a.meterName}  ·  ${a.site}'
                                : a.meterName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final item in a.items) ...[
                      Text(
                        '• ${item.issue}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                          '↳ ${item.solution}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

}

class _SavingOpportunityCard extends StatelessWidget {
  final SavingOpportunity opportunity;
  const _SavingOpportunityCard({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (opportunity.type) {
      SavingType.demandReduction => (
        Icons.trending_down_rounded,
        AppColors.kpiDemand,
      ),
      SavingType.powerFactorImprovement => (
        Icons.waves_rounded,
        AppColors.kpiPower,
      ),
      SavingType.loadSmoothing => (
        Icons.linear_scale_rounded,
        AppColors.kpiEnergy,
      ),
      SavingType.contractDemandOptimization => (
        Icons.description_rounded,
        AppColors.kpiCost,
      ),
    };
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹${opportunity.monthlySavings.toStringAsFixed(0)}/month',
            style: AppTypography.mono(
              size: 24,
              weight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.description,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  opportunity.action,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final InsightItem insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData icon;
    switch (insight.severity) {
      case InsightSeverity.positive:
        bgColor = AppColors.success;
        iconColor = AppColors.success;
        icon = Icons.check_circle_rounded;
      case InsightSeverity.neutral:
        bgColor = AppColors.primary;
        iconColor = AppColors.primary;
        icon = Icons.info_rounded;
      case InsightSeverity.warning:
        bgColor = AppColors.warning;
        iconColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
      case InsightSeverity.critical:
        bgColor = AppColors.danger;
        iconColor = AppColors.danger;
        icon = Icons.error_rounded;
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (insight.recommendation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          insight.recommendation!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final RecommendationItem rec;
  const _RecommendationCard({required this.rec});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rec.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Priority ${rec.priority}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rec.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rec.action,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (rec.estimatedSavings != null &&
                    rec.estimatedSavings! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.savings_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Potential savings: ₹${rec.estimatedSavings!.toStringAsFixed(0)}/month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
