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
import '../../core/widgets/month_filter_bar.dart';
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
          EnergyValidationError _ => Center(child: Text(state.message)),
          EnergyOperationFailure _ => Center(child: Text(state.message)),
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
      // Read the first file's headers to let the user confirm the column
      // mapping (auto-detection is prefilled). This fits every client file
      // format, e.g. kVA demand recorded under "Contract KVA".
      ExcelColumnMap? columnMap;
      if (result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          final headers = await ExcelImportService.readHeaders(bytes);
          final detected = ExcelImportService.detectMapping(headers);
          if (context.mounted) {
            columnMap = await showDialog<ExcelColumnMap>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _ColumnMappingDialog(
                headers: headers,
                initial: detected,
              ),
            );
          }
        }
      }
      if (columnMap == null) return;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        sourceFile = file.name;
        drafts.addAll(
          await ExcelImportService.extractReadings(
            bytes,
            columnMap: columnMap,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Excel import failed', e);
      if (context.mounted) {
        final message = e is FormatException
            ? e.message
            : 'Import failed. Check the file and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
                                '${_selection.label}${_meter != null ? ', $_meter' : ''}',
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
        if (isNarrow) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                            '${_selection.label}${_meter != null ? ', $_meter' : ''}',
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
              MonthFilterBar(
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
                child: MonthFilterBar(
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
    return Column(
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

/// Preview + edit screen for readings parsed from an Excel file.
/// Nothing is saved until the user confirms (Issue 11 — manual edit mandatory).
class _ColumnMappingDialog extends StatefulWidget {
  final List<String> headers;
  final ExcelColumnMap initial;

  const _ColumnMappingDialog({
    required this.headers,
    required this.initial,
  });

  @override
  State<_ColumnMappingDialog> createState() => _ColumnMappingDialogState();
}

class _ColumnMappingDialogState extends State<_ColumnMappingDialog> {
  late final ExcelColumnMap _map = widget.initial;

  String _colName(int index) {
    var n = index;
    var label = '';
    while (n >= 0) {
      label = String.fromCharCode(65 + (n % 26)) + label;
      n = n ~/ 26 - 1;
    }
    return label;
  }

  Widget _fieldDropdown({
    required String label,
    required int? value,
    required void Function(int?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: [
          const DropdownMenuItem<int>(value: -1, child: Text('— Auto —')),
          for (var i = 0; i < widget.headers.length; i++)
            if (widget.headers[i].trim().isNotEmpty)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  '${_colName(i)}: ${widget.headers[i].trim()}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Column Mapping'),
      content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Auto-detection is prefilled. Adjust if your client file '
                'uses different column names (e.g. kVA demand under '
                '"Contract KVA").',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              _fieldDropdown(
                label: 'Reading Date',
                value: _map.date,
                onChanged: (v) => setState(() => _map.date = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'kWh (consumed or cumulative)',
                value: _map.kwh,
                onChanged: (v) => setState(() => _map.kwh = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'kVAh',
                value: _map.kvah,
                onChanged: (v) => setState(() => _map.kvah = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Max Demand kVA',
                value: _map.md,
                onChanged: (v) => setState(() => _map.md = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'rkVARh Lag',
                value: _map.lag,
                onChanged: (v) => setState(() => _map.lag = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'rkVARh Lead',
                value: _map.lead,
                onChanged: (v) => setState(() => _map.lead = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Power Factor (as-is)',
                value: _map.pf,
                onChanged: (v) => setState(() => _map.pf = v == -1 ? null : v),
              ),
              _fieldDropdown(
                label: 'Meter Name',
                value: _map.meter,
                onChanged: (v) =>
                    setState(() => _map.meter = v == -1 ? null : v),
              ),
            ],
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_map),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

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
          currentKwh: e.currentKwh,
          currentKvah: e.currentKvah,
          rkvarhLag: e.lag,
          rkvarhLead: e.lead,
          powerFactor: e.powerFactor,
          mdRecorded: e.md,
          contractDemand:
              meter?.contractDemandKw ?? AppConstants.defaultContractDemandKva,
          loggedAt: e.loggedAt,
          multiplyingFactor:
              meter?.multiplyingFactor ?? AppConstants.multiplyingFactor,
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
          content: Text(
            e is FormatException
                ? e.message
                : 'Import failed. Check the file and try again.',
          ),
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
        width: MediaQuery.of(context).size.width < 600
            ? double.maxFinite
            : 620,
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
                    label: 'Consumed (kWh)',
                    prefixIcon: Icons.bolt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.kvahCtrl,
                    label: 'Consumed kVAh',
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
                    controller: e.currentKwhCtrl,
                    label: 'Actual Reading kWh',
                    hint: 'Optional — meter display value',
                    prefixIcon: Icons.speed,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: e.currentKvahCtrl,
                    label: 'Actual Reading kVAh',
                    hint: 'Optional',
                    prefixIcon: Icons.speed,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (MediaQuery.of(context).size.width < 600)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: e.mdCtrl,
                          label: 'MD Recorded (kVA)',
                          prefixIcon: Icons.trending_up,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: e.pfCtrl,
                          label: 'Power Factor',
                          prefixIcon: Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: e.lagCtrl,
                          label: 'rkVARh Lag',
                          prefixIcon: Icons.warning_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: e.leadCtrl,
                          label: 'rkVARh Lead',
                          prefixIcon: Icons.check_circle_outline,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
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
                    controller: e.pfCtrl,
                    label: 'Power Factor',
                    prefixIcon: Icons.percent,
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
      currentKwhCtrl = TextEditingController(
        text: draft.currentKwh != null
            ? draft.currentKwh!.toStringAsFixed(2)
            : '',
      ),
      currentKvahCtrl = TextEditingController(
        text: draft.currentKvah != null
            ? draft.currentKvah!.toStringAsFixed(2)
            : '',
      ),
      lagCtrl = TextEditingController(text: _fmt(draft.rkvarhLag)),
      leadCtrl = TextEditingController(text: _fmt(draft.rkvarhLead)),
      mdCtrl = TextEditingController(text: _fmt(draft.mdRecorded)),
      pfCtrl = TextEditingController(
        text: draft.powerFactor != null
            ? draft.powerFactor!.toStringAsFixed(3)
            : '',
      );

  final ExcelReadingDraft draft;
  String meterName = '';
  final TextEditingController dateCtrl;
  final TextEditingController kwhCtrl;
  final TextEditingController kvahCtrl;
  final TextEditingController currentKwhCtrl;
  final TextEditingController currentKvahCtrl;
  final TextEditingController lagCtrl;
  final TextEditingController leadCtrl;
  final TextEditingController mdCtrl;
  final TextEditingController pfCtrl;

  static String _fmt(double v) => v > 0 ? v.toStringAsFixed(2) : '';

  double get kwh => double.tryParse(kwhCtrl.text.trim()) ?? 0;
  double get kvah => double.tryParse(kvahCtrl.text.trim()) ?? 0;
  double get md => double.tryParse(mdCtrl.text.trim()) ?? 0;
  double get lag => double.tryParse(lagCtrl.text.trim()) ?? 0;
  double get lead => double.tryParse(leadCtrl.text.trim()) ?? 0;

  /// Actual (cumulative) meter reading — blank means "not known" (the system
  /// reconstructs it from the consumption chain on read).
  double? get currentKwh {
    final v = double.tryParse(currentKwhCtrl.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  double? get currentKvah {
    final v = double.tryParse(currentKvahCtrl.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  /// PF as imported from the file (or edited by the user). Null → let the
  /// system calculate from kWh/kVAh.
  double? get powerFactor {
    final v = double.tryParse(pfCtrl.text.trim());
    if (v == null || v <= 0) return null;
    return v > 1 ? v / 100 : v;
  }

  /// Importable when it has consumption or an actual reading, plus MD.
  /// Opening rows (0 consumption, real reading) anchor the reading chain.
  bool get valid => (kwh > 0 || currentKwh != null) && md > 0;

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
    currentKwhCtrl.dispose();
    currentKvahCtrl.dispose();
    lagCtrl.dispose();
    leadCtrl.dispose();
    mdCtrl.dispose();
    pfCtrl.dispose();
  }
}
