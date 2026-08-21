import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';

class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  List<EnergyLogEntity> _allLogs = [];
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;
  int _visibleCount = 20;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await context.read<EnergyRepository>().getAllLogs();
      if (mounted) {
        final sorted = List<EnergyLogEntity>.from(logs)
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        setState(() {
          _allLogs = sorted;
          final now = DateTime.now();
          _selectedYear ??= now.year;
        });
      }
    } catch (_) {}
  }

  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final l in _filteredByYear) {
      years.add(l.loggedAt.year);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<EnergyLogEntity> get _filteredByYear {
    if (_selectedYear == null) return _allLogs;
    return _allLogs.where((l) => l.loggedAt.year == _selectedYear).toList();
  }

  List<int> get _availableMonths {
    final months = <int>{};
    for (final l in _filteredByYear) {
      months.add(l.loggedAt.month);
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  List<EnergyLogEntity> get _filteredByMonth {
    var logs = _filteredByYear;
    if (_selectedMonth != null) {
      logs = logs.where((l) => l.loggedAt.month == _selectedMonth).toList();
    }
    return logs;
  }

  List<int> get _availableDays {
    final days = <int>{};
    for (final l in _filteredByMonth) {
      days.add(l.loggedAt.day);
    }
    return days.toList()..sort((a, b) => b.compareTo(a));
  }

  List<EnergyLogEntity> get _filtered {
    var logs = _filteredByMonth;
    if (_selectedDay != null) {
      logs = logs.where((l) => l.loggedAt.day == _selectedDay).toList();
    }
    return logs;
  }

  String _fmtDate(DateTime dt) => DateFormat('dd MMM yyyy, HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_visibleCount).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _buildFilterRow(),
          const SizedBox(height: 16),
          if (_allLogs.isEmpty)
            AppCard(
              child: SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 32, color: dim),
                      const SizedBox(height: 8),
                      Text('No readings found', style: TextStyle(fontSize: 13, color: dim)),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Text(
              '${filtered.length} reading(s) — tap to edit',
              style: TextStyle(fontSize: 12, color: dim),
            ),
            const SizedBox(height: 8),
            for (final log in visible) _buildReadingCard(log),
            if (_visibleCount < filtered.length)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _visibleCount += _pageSize),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Load More'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _dropdown<int>(
          label: 'Year',
          value: _selectedYear,
          items: _availableYears,
          labelBuilder: (v) => '$v',
          onChanged: (v) => setState(() {
            _selectedYear = v;
            _selectedMonth = null;
            _selectedDay = null;
            _visibleCount = _pageSize;
          }),
        ),
        _dropdown<int>(
          label: 'Month',
          value: _selectedMonth,
          items: _availableMonths,
          labelBuilder: (v) => DateFormat('MMMM').format(DateTime(2024, v)),
          onChanged: (v) => setState(() {
            _selectedMonth = v;
            _selectedDay = null;
            _visibleCount = _pageSize;
          }),
        ),
        _dropdown<int>(
          label: 'Day',
          value: _selectedDay,
          items: _availableDays,
          labelBuilder: (v) => '$v',
          onChanged: (v) => setState(() {
            _selectedDay = v;
            _visibleCount = _pageSize;
          }),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All', style: TextStyle(fontSize: 13)),
          ),
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item), style: TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReadingCard(EnergyLogEntity log) {
    final mf = log.multiplyingFactor;
    final actualMd = log.mdRecorded * mf;
    final actualKwh = log.kwh * mf;
    final actualKvah = log.kvah * mf;
    final pf = log.kvah > 0 ? (log.kwh / log.kvah).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditDialog(log),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _fmtDate(log.loggedAt),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.meterName,
                    style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('kWh', actualKwh.toStringAsFixed(1)),
                _chip('kVAh', actualKvah.toStringAsFixed(1)),
                _chip('MD', '${actualMd.toStringAsFixed(1)} kVA'),
                _chip('PF', '${(pf * 100).toStringAsFixed(1)}%'),
                _chip('MF', '${mf}x'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2Light.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
                    rkvarhLead: double.tryParse(rkvarhLeadCtrl.text.trim()) ?? 0,
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
                      _loadLogs();
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
}
