import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Month selection shared by all analytics screens.
///
/// - [month] == null and [allTime] == false → "This Month": auto-follows the
///   current month, so every screen shows live data when a new month starts.
/// - [allTime] == true → no month filter (Reports "All Time").
/// - otherwise → the exact (year, month) the user picked.
class MonthFilterValue {
  const MonthFilterValue.current() : month = null, allTime = false;
  const MonthFilterValue.allTime() : month = null, allTime = true;
  const MonthFilterValue.month(DateTime this.month) : allTime = false;

  final DateTime? month;
  final bool allTime;

  bool get isCurrent => month == null && !allTime;

  /// Whether [loggedAt] belongs to the selected period.
  bool matches(DateTime loggedAt) {
    if (allTime) return true;
    final m = month ?? DateTime.now();
    return loggedAt.year == m.year && loggedAt.month == m.month;
  }

  String get label {
    if (allTime) return 'All Time';
    final m = month ?? DateTime.now();
    return DateFormat('MMMM yyyy').format(m);
  }

  @override
  bool operator ==(Object other) {
    if (other is! MonthFilterValue) return false;
    if (other.allTime != allTime) return false;
    if (month == null || other.month == null) return month == other.month;
    return month!.year == other.month!.year &&
        month!.month == other.month!.month;
  }

  @override
  int get hashCode => Object.hash(allTime, month?.year, month?.month);
}

/// ValueNotifier holding the shared month selection.
class MonthFilterController extends ValueNotifier<MonthFilterValue> {
  MonthFilterController() : super(const MonthFilterValue.current());
}

/// Top filter bar: "This Month" + every month present in the data + optional
/// "All Time" + a calendar picker for any month.
///
/// Place it at the top of every analytics screen — the same controller is
/// shared across screens, so picking a month on one screen applies everywhere.
class MonthFilterBar extends StatelessWidget {
  final MonthFilterController controller;

  /// Distinct months present in the data (any order — deduped + sorted here).
  final List<DateTime> availableMonths;

  /// Show the "All Time" option (used by Reports).
  final bool includeAllTime;

  const MonthFilterBar({
    super.key,
    required this.controller,
    required this.availableMonths,
    this.includeAllTime = false,
  });

  Future<void> _pickMonth(BuildContext context, MonthFilterValue current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.month ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    controller.value = MonthFilterValue.month(
      DateTime(picked.year, picked.month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seen = <String, DateTime>{};
    final months = <DateTime>[];
    for (final m in availableMonths) {
      final key = '${m.year}-${m.month}';
      if (seen.containsKey(key)) continue;
      seen[key] = m;
      months.add(DateTime(m.year, m.month));
    }
    months.sort((a, b) => b.compareTo(a));

    return ValueListenableBuilder<MonthFilterValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                label: 'This Month',
                selected: value.isCurrent,
                onTap: () => controller.value = const MonthFilterValue.current(),
              ),
              if (includeAllTime) ...[
                const SizedBox(width: 4),
                _chip(
                  label: 'All Time',
                  selected: value.allTime,
                  onTap: () => controller.value = const MonthFilterValue.allTime(),
                ),
              ],
              for (final m in months) ...[
                const SizedBox(width: 4),
                _chip(
                  label: DateFormat('MMM yy').format(m),
                  selected: !value.allTime &&
                      !value.isCurrent &&
                      value.month!.year == m.year &&
                      value.month!.month == m.month,
                  onTap: () => controller.value = MonthFilterValue.month(m),
                ),
              ],
              const SizedBox(width: 4),
              _chip(
                label: DateFormat('MMM yyyy').format(
                  value.month ?? DateTime.now(),
                ),
                icon: Icons.calendar_month,
                selected: false,
                onTap: () => _pickMonth(context, value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
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
}

