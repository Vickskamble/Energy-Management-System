import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/energy_log_entity.dart';

/// Bottom sheet showing the full readings behind a tapped chart point
/// (one month on the dashboard charts, one day on the analysis trends).
void showReadingsPreviewSheet(
  BuildContext context, {
  required String title,
  required List<EnergyLogEntity> logs,
}) {
  final sorted = [...logs]
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReadingsPreviewSheet(title: title, logs: sorted),
  );
}

class _ReadingsPreviewSheet extends StatelessWidget {
  const _ReadingsPreviewSheet({required this.title, required this.logs});

  final String title;
  final List<EnergyLogEntity> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final border = theme.brightness == Brightness.dark
        ? AppColors.borderDark
        : AppColors.borderLight;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.dim(context),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight - 100),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                shrinkWrap: true,
                itemCount: logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReadingCard(log: logs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.log});

  final EnergyLogEntity log;

  @override
  Widget build(BuildContext context) {
    final mf = log.multiplyingFactor;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  log.meterName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy · hh:mm a').format(log.loggedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dim(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(
                label: 'kWh',
                value: '${(log.kwh * mf).toStringAsFixed(1)} kWh',
              ),
              _Stat(
                label: 'kVAh',
                value: '${(log.kvah * mf).toStringAsFixed(1)} kVAh',
              ),
              _Stat(
                label: 'MD',
                value: '${log.actualMd.toStringAsFixed(1)} kVA',
              ),
              if (log.mdValues != null && log.mdValues!.length >= 4) ...[
                _Stat(
                  label: 'MD T1',
                  value: '${log.mdValues![0].toStringAsFixed(1)} kVA',
                ),
                _Stat(
                  label: 'MD T2',
                  value: '${log.mdValues![1].toStringAsFixed(1)} kVA',
                ),
                _Stat(
                  label: 'MD T3',
                  value: '${log.mdValues![2].toStringAsFixed(1)} kVA',
                ),
                _Stat(
                  label: 'MD T4',
                  value: '${log.mdValues![3].toStringAsFixed(1)} kVA',
                ),
              ],
              _Stat(
                label: 'PF',
                value: log.powerFactor.toStringAsFixed(2),
              ),
              _Stat(
                label: 'Load Factor',
                value: '${(log.loadFactor * 100).toStringAsFixed(0)}%',
              ),
              _Stat(
                label: 'MF',
                value: '×${mf.toStringAsFixed(1)}',
              ),
              _Stat(
                label: 'Contract',
                value: '${log.contractDemand.toStringAsFixed(0)} kVA',
              ),
              if (log.billingDemand > 0)
                _Stat(
                  label: 'Billing MD',
                  value: '${log.billingDemand.toStringAsFixed(0)} kVA',
                ),
              if (log.netBill > 0)
                _Stat(
                  label: 'Net Bill',
                  value: '₹${log.netBill.toStringAsFixed(0)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.sidebarItemActiveDark
            : AppColors.sidebarItemActive,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.dim(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}