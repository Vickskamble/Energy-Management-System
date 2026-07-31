import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final double? columnWidth;
  final bool stickyHeader;

  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnWidth,
    this.stickyHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            columnSpacing: columnWidth ?? 120,
            horizontalMargin: AppSpacing.lg,
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            ),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return AppColors.primary.withValues(alpha: 0.04);
              }
              return Colors.transparent;
            }),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.5,
              ),
            ),
            columns: columns
                .map(
                  (col) => DataColumn(
                    label: Text(
                      col,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: row
                        .map(
                          (cell) => DataCell(
                            DefaultTextStyle(
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary,
                              ),
                              child: cell,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
