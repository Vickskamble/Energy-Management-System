import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
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

class DashboardPage extends StatefulWidget {
  /// Only refresh automatically while this tab is visible.
  final bool isActive;

  /// Shared month filter — Dashboard, Analysis & Reports stay in sync.
  final MonthFilterController monthFilter;

  const DashboardPage({
    super.key,
    this.isActive = true,
    required this.monthFilter,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _startAutoRefresh();
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
          if (state.currentPowerFactor < AppConstants.pfPenaltyThreshold) {
            NotificationService.instance.showPfAlert(state.currentPowerFactor);
          }
          if (state.maxDemandPeak >= AppConstants.mdWarningThresholdKva) {
            NotificationService.instance.showMdAlert(
              state.maxDemandPeak,
              AppConfig.contractDemandKva,
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

  const _DashboardContent({required this.logs, required this.monthFilter});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  String? _site;
  String? _meter;
  DateTime? _selectedDate;
  Map<String, String> _meterSites = {};

  MonthFilterValue get _selection => widget.monthFilter.value;

  @override
  void initState() {
    super.initState();
    _loadMeterSites();
    widget.monthFilter.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant _DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthFilter != widget.monthFilter) {
      oldWidget.monthFilter.removeListener(_onFilterChanged);
      widget.monthFilter.addListener(_onFilterChanged);
    }
  }

  @override
  void dispose() {
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
        _meterSites = {for (final m in meters) m.name: m.site};
      });
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
  List<String> get _meterNames {
    final names = <String>{
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

  DateTime? get _earliestLogDate {
    if (_siteLogs.isEmpty) return null;
    final sorted = _siteLogs.map((l) => l.loggedAt).toList()..sort();
    return sorted.first;
  }

  DateTime? get _latestLogDate {
    if (_siteLogs.isEmpty) return null;
    final sorted = _siteLogs.map((l) => l.loggedAt).toList()
      ..sort((a, b) => b.compareTo(a));
    return sorted.first;
  }

  void _enableDayMode() {
    if (_selectedDate != null) {
      setState(() {});
      return;
    }
    final now = DateTime.now();
    final hasToday = _siteLogs.any((l) => _isSameDay(l.loggedAt, now));
    setState(() {
      _selectedDate = hasToday
          ? now
          : (_latestLogDate ?? now);
    });
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
      setState(() => _selectedDate = picked);
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
  List<DateTime> get _availableMonths {
    final keys = <String, DateTime>{};
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
  double get _siteEstimatedBill {
    return BillCalculator.calculate(
      logs: _selectedLogs,
      ratchetLogs: _siteLogs,
      demandRate: _isDayMode ? 0 : null,
    ).netBill;
  }

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

  double get _sitePowerFactor {
    return BillCalculator.calculate(
      logs: _selectedLogs,
      ratchetLogs: _siteLogs,
    ).powerFactor;
  }

  /// Visible formula for the Power Factor card: per-meter PF as recorded
  /// by the client (meter display / Excel) — never recomputed. Lets the
  /// user see exactly which meter drives the combined value.
  String get _powerFactorBreakdown {
    if (_selectedLogs.isEmpty) return 'No readings — kVAh data add karo';
    final perMeter = <String, ({double kwh, double kvah, double pfSum})>{};
    var sumKwh = 0.0;
    var sumKvah = 0.0;
    var sumPf = 0.0;
    for (final l in _selectedLogs) {
      final kwh = l.kwh * l.multiplyingFactor;
      final kvah = l.kvah * l.multiplyingFactor;
      final rec = perMeter.putIfAbsent(
        l.meterName,
        () => (kwh: 0, kvah: 0, pfSum: 0),
      );
      perMeter[l.meterName] = (
        kwh: rec.kwh + kwh,
        kvah: rec.kvah + kvah,
        pfSum: rec.pfSum + l.powerFactor * kwh,
      );
      sumKwh += kwh;
      sumKvah += kvah;
      sumPf += l.powerFactor * kwh;
    }
    final nf = NumberFormat.decimalPattern('en_IN');
    final lines = <String>[
      sumPf > 0
          ? 'As recorded (weighted): ${(sumPf / sumKwh).toStringAsFixed(3)}'
          : 'Auto: ${nf.format(sumKwh)} kWh \u00f7 ${nf.format(sumKvah)} kVAh'
              '${sumKvah > 0 ? ' = ${(sumKwh / sumKvah).toStringAsFixed(3)}' : ''}',
    ];
    for (final e in perMeter.entries) {
      final d = e.value;
      final pf = d.pfSum > 0
          ? 'PF ${(d.pfSum / d.kwh).toStringAsFixed(3)}'
          : (d.kvah > 0
                ? 'PF ${(d.kwh / d.kvah).toStringAsFixed(3)} (auto)'
                : 'PF —');
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
    final days = DateTime(
      _selection.month!.year,
      _selection.month!.month + 1,
      0,
    ).day;
    return (total / days * 100).roundToDouble() / 100;
  }

  Widget _modeChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: AppColors.primary),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildSiteSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _siteChip('All Sites', null),
          for (final site in _siteNames) _siteChip(site, site),
        ],
      ),
    );
  }

  Widget _buildMeterSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _meterChip('All Meters', null),
          for (final meter in _meterNames) _meterChip(meter, meter),
        ],
      ),
    );
  }

  Widget _meterChip(String label, String? value) {
    final selected = _meter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          Icons.speed_rounded,
          size: 16,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _meter = value),
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
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

  Widget _siteChip(String label, String? value) {
    final selected = _site == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _site = value),
        selectedColor: AppColors.kpiSavings.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.kpiSavings : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? AppColors.kpiSavings : AppColors.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final refMonth = isCurrentMonth
        ? null
        : DateTime(_selection.month!.year, _selection.month!.month);
    final previousMonth = refMonth == null
        ? DateTime(now.year, now.month - 1, 1)
        : DateTime(refMonth.year, refMonth.month - 1, 1);
    final previousLogs = _isDayMode
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
    final currentBreakdown = periodLogs.isEmpty
        ? null
        : BillCalculator.calculate(
            logs: periodLogs,
            ratchetLogs: entityLogs,
            demandRate: dayMode ? 0 : null,
          );
    final previousBreakdown = previousLogs.isEmpty
        ? null
        : BillCalculator.calculate(
            logs: previousLogs,
            ratchetLogs: entityLogs,
            demandRate: dayMode ? 0 : null,
          );
    final comparison = currentBreakdown == null
        ? null
        : BillCalculator.compare(currentBreakdown, previousBreakdown);
    // Forecast is meaningful only for the live (current) month.
    final forecast = !_isDayMode && isCurrentMonth
        ? BillForecastCalculator.calculate(
            monthLogs: periodLogs,
            referenceDate: now,
            ratchetLogs: entityLogs,
          )
        : null;
    // Saving opportunities are ₹/month figures — always computed from the
    // month's data, even in Daily mode (a day's zero demand rate would
    // otherwise zero out demand-reduction savings).
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

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (_siteNames.isNotEmpty) ...[
            _buildSiteSelector(),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_meterNames.isNotEmpty) ...[
            _buildMeterSelector(),
            const SizedBox(height: AppSpacing.sm),
          ],
          MonthFilterBar(
            controller: widget.monthFilter,
            availableMonths: _availableMonths,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _modeChip(
                'Monthly',
                selected: !_isDayMode,
                onTap: () => setState(() => _selectedDate = null),
              ),
              _modeChip('Daily', selected: _isDayMode, onTap: _enableDayMode),
              if (_isDayMode)
                _modeChip(
                  DateFormat('d MMM yyyy').format(_selectedDate!),
                  selected: true,
                  icon: Icons.calendar_month,
                  onTap: _pickDate,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildAlertBanner(context),
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

          if (periodLogs.isEmpty) ...[
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
                    '$_kpiMonthLabel${breakdown.totalUnits.toStringAsFixed(0)} billed units',
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
                    ? 'No kVAh data — readings me kVAh enter karo'
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
                title: _isDayMode ? 'Readings' : (_selection.isCurrent ? "Today's Usage" : 'Daily Avg'),
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

          _buildAlertsSection(context),
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
                        child: DashboardChart(logs: entityLogs),
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
                        child: MonthlyConsumptionChart(logs: entityLogs),
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
                          child: DashboardChart(logs: entityLogs),
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
                          child: MonthlyConsumptionChart(logs: entityLogs),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xxl),

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
                      ? 'Is day abhi tak koi reading nahi'
                      : 'Is month abhi tak koi reading nahi',
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
                  'Bill forecast sirf Monthly mode me available hai — "Monthly" select karo',
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
                  'Is month abhi tak koi reading nahi',
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
              'Aaj ki usage rate par estimated — readings badhne par update hoga',
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

  Widget _buildAlertBanner(BuildContext context) {
    final pf = _sitePowerFactor;
    final hasPfIssue = pf > 0 && pf < AppConstants.pfPenaltyThreshold;
    final hasMdIssue = _siteMaxDemandPeak >= AppConstants.mdWarningThresholdKva;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = hasPfIssue || hasMdIssue
        ? AppColors.warning
        : AppColors.success;
    final IconData icon = hasPfIssue || hasMdIssue
        ? Icons.warning_amber_rounded
        : Icons.check_circle_rounded;
    final String text;
    if (hasPfIssue && hasMdIssue) {
      text = '2 alerts — PF penalty & Max Demand high';
    } else if (hasPfIssue) {
      text = '1 alert — Low PF (below ${AppConstants.pfPenaltyThreshold})';
    } else if (hasMdIssue) {
      text = '1 alert — Max Demand high';
    } else {
      text = 'All systems normal';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final pf = _sitePowerFactor;
    final hasPfIssue = pf > 0 && pf < AppConstants.pfPenaltyThreshold;
    final hasMdIssue = _siteMaxDemandPeak >= AppConstants.mdWarningThresholdKva;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'System Alerts',
          subtitle: hasPfIssue || hasMdIssue
              ? 'Action required'
              : 'All systems normal',
        ),
        if (pf == 0)
          AppCard(
            color: AppColors.warning.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Power Factor data missing — readings me kVAh value add karo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (!hasPfIssue && !hasMdIssue)
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
                const Expanded(
                  child: Text(
                    'All parameters within normal limits',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasPfIssue)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              color: AppColors.danger.withValues(alpha: 0.05),
              child: Row(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Problem: Low PF Penalty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PF is ${_sitePowerFactor.toStringAsFixed(3)} (below 0.95). A 5% reactive penalty applies.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Solution: Check APFC Panel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasMdIssue)
          AppCard(
            color: AppColors.warning.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warning: Near MD Breach',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Max demand at ${_siteMaxDemandPeak.toStringAsFixed(1)} kVA, approaching ${AppConstants.mdWarningThresholdKva.toInt()} kVA contract limit.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
