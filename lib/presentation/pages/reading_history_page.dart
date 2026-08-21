import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../data/repositories/energy_repository.dart';
import '../../domain/entities/energy_log_entity.dart';

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

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Reading History',
          subtitle: 'Browse all readings by year, month and day',
        ),
        const SizedBox(height: 12),
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
            '${filtered.length} reading(s)',
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
}
