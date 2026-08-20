import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/subscription_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import 'billing_page.dart';

class MeterManagementPage extends StatelessWidget {
  const MeterManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MeterList();
  }

  static Future<void> showMeterDialog(
    BuildContext context, {
    MeterModel? existing,
  }) async {
    // Meter name cannot change once readings exist against it — renaming
    // breaks the previous-reading chain (consumed = current − previous) and
    // manufactures bill spikes (e.g. "Maintenance Feeder" → "Main Feeder").
    var hasReadings = false;
    if (existing != null) {
      try {
        hasReadings = await context
                .read<EnergyRepository>()
                .getLatestReading(existing.name) !=
            null;
      } catch (_) {
        // Offline / fetch failure → keep the lock off and re-check on save.
      }
    }
    final nameLocked = existing != null && hasReadings;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final demandCtrl = TextEditingController(
      text: existing?.contractDemandKw.toStringAsFixed(0) ?? '400',
    );
    final ctCtrl = TextEditingController(
      text: existing?.ctRatio.toStringAsFixed(2) ?? '1',
    );
    final ptCtrl = TextEditingController(
      text: existing?.ptRatio.toStringAsFixed(2) ?? '1',
    );
    final siteCtrl = TextEditingController(text: existing?.site ?? 'Main Site');
    final targetCtrl = TextEditingController(
      text: existing != null && existing.dailyKwhTarget > 0
          ? existing.dailyKwhTarget.toStringAsFixed(0)
          : '',
    );
    final formKey = GlobalKey<FormState>();

    if (!context.mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Meter' : 'Add Meter'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              AppTextField(
                controller: nameCtrl,
                label: 'Meter Name',
                prefixIcon: Icons.speed_rounded,
                maxLength: 60,
                readOnly: nameLocked,
                hint: nameLocked
                    ? 'Locked — readings already exist'
                    : null,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              if (nameLocked) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Name is locked because readings exist for this '
                          'meter — renaming would break consumption tracking. '
                          'Other fields can still be edited.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                controller: locationCtrl,
                label: 'Location (optional)',
                prefixIcon: Icons.location_on_outlined,
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: demandCtrl,
                label: 'Contract Demand (kVA)',
                prefixIcon: Icons.trending_up,
                keyboardType: TextInputType.number,
                inputFormatters: [AppInputFormatters.numeric],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (AppInputFormatters.parseNumber(v.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: targetCtrl,
                label: 'Daily Avg Consumption Target (kWh/day)',
                hint: 'Optional — sets the chart cross line and alerts',
                prefixIcon: Icons.electric_bolt_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [AppInputFormatters.numeric],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = AppInputFormatters.parseNumber(v.trim());
                  if (val == null || val <= 0) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: ctCtrl,
                      label: 'CT Ratio',
                      hint: 'e.g. 100/5 = 20',
                      prefixIcon: Icons.tune,
                      keyboardType: TextInputType.number,
                      inputFormatters: [AppInputFormatters.numeric],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = AppInputFormatters.parseNumber(v.trim());
                        if (val == null || val <= 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: ptCtrl,
                      label: 'PT Ratio',
                      hint: '1 if none',
                      prefixIcon: Icons.tune,
                      keyboardType: TextInputType.number,
                      inputFormatters: [AppInputFormatters.numeric],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = AppInputFormatters.parseNumber(v.trim());
                        if (val == null || val <= 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: siteCtrl,
                label: 'Site (factory/plant)',
                hint: 'e.g. Unit 1, Pune',
                prefixIcon: Icons.factory_outlined,
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Multiplying Factor (MF) = CT × PT — meter readings are multiplied by this value',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Save',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = context.read<MeterRepository>();
              final energyRepo = context.read<EnergyRepository>();
              final messenger = ScaffoldMessenger.of(ctx);
              final nav = Navigator.of(ctx);
              // Hard guard: never allow a rename once readings exist —
              // re-verified over the network so a failed lock fetch at
              // dialog-open can never slip a rename through.
              final willRename =
                  existing != null && nameCtrl.text.trim() != existing.name;
              if (willRename) {
                var locked = nameLocked;
                if (!locked) {
                  try {
                    locked =
                        await energyRepo.getLatestReading(existing.name) !=
                            null;
                  } catch (_) {
                    // Unreachable → reject the rename to stay safe.
                    locked = true;
                  }
                }
                if (locked) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Meter name cannot be changed — readings already '
                        'exist against this meter.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }
              final meter = existing != null
                  ? MeterModel(
                      id: existing.id,
                      name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty
                          ? null
                          : locationCtrl.text.trim(),
                      contractDemandKw:
                          AppInputFormatters.parseNumber(demandCtrl.text.trim())!,
                      isActive: existing.isActive,
                      ctRatio: AppInputFormatters.parseNumber(ctCtrl.text.trim())!,
                      ptRatio: AppInputFormatters.parseNumber(ptCtrl.text.trim())!,
                      site: siteCtrl.text.trim().isEmpty
                          ? 'Main Site'
                          : siteCtrl.text.trim(),
                      dailyKwhTarget: targetCtrl.text.trim().isEmpty
                          ? 0.0
                          : AppInputFormatters.parseNumber(
                              targetCtrl.text.trim())!,
                    )
                  : MeterModel.create(
                      name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty
                          ? null
                          : locationCtrl.text.trim(),
                      contractDemandKw:
                          AppInputFormatters.parseNumber(demandCtrl.text.trim())!,
                      ctRatio: AppInputFormatters.parseNumber(ctCtrl.text.trim())!,
                      ptRatio: AppInputFormatters.parseNumber(ptCtrl.text.trim())!,
                      site: siteCtrl.text.trim().isEmpty
                          ? 'Main Site'
                          : siteCtrl.text.trim(),
                      dailyKwhTarget: targetCtrl.text.trim().isEmpty
                          ? 0.0
                          : AppInputFormatters.parseNumber(
                              targetCtrl.text.trim())!,
                    );
              try {
                if (existing != null) {
                  repo.updateMeter(meter);
                } else {
                  repo.saveMeter(meter);
                }
                nav.pop(true);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Meter save failed — $e',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MeterList extends StatefulWidget {
  @override
  State<_MeterList> createState() => _MeterListState();
}

class _MeterListState extends State<_MeterList> {
  List<MeterModel> _meters = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    context.read<MeterRepository>().addListener(_load);
  }

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MeterRepository>();
      final meters = await repo.getAllMeters();
      if (!mounted) return;
      setState(() {
        _meters = meters;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load meters. Check your connection and retry.';
        _meters = const [];
      });
    }
  }

  List<MeterModel> get _filteredMeters {
    if (_searchQuery.isEmpty) return _meters;
    return _meters
        .where(
          (m) =>
              m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (m.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppErrorState(
        message: _error!,
        onRetry: _load,
      );
    }

    if (_meters.isEmpty) {
      return Stack(
        children: [
          const AppEmptyState(
            icon: Icons.speed_rounded,
            title: 'No meters configured',
            subtitle: 'Tap + to add your first meter',
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _addMeterFab(context),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.page,
                AppSpacing.page,
                0,
              ),
              child: AppSectionHeader(
                title: 'Meter Management',
                subtitle: '${_meters.length} meter(s) configured',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search meters...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    88,
                  ),
                  itemCount: _filteredMeters.length,
                  itemBuilder: (context, index) {
                    final meter = _filteredMeters[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    (meter.isActive
                                            ? AppColors.success
                                            : AppColors.textSecondary)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                meter.isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: meter.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meter.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${meter.site} — Contract: ${meter.contractDemandKw.toStringAsFixed(0)} kVA — MF: ${meter.multiplyingFactor.toStringAsFixed(2)}${meter.location != null ? ' — ${meter.location}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () async {
                                await MeterManagementPage.showMeterDialog(
                                  context,
                                  existing: meter,
                                );
                                _load();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.danger,
                              ),
                              onPressed: () async {
                                final repo = context.read<MeterRepository>();
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Meter'),
                                    content: Text(
                                      'Meter "${meter.name}" and all of its readings will be permanently deleted. Are you sure?',
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await repo.deleteMeter(meter.id);
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: _addMeterFab(context),
        ),
      ],
    );
  }

  Widget _addMeterFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final repo = context.read<MeterRepository>();
        final meters = await repo.getAllMeters();
        final canAdd = await SubscriptionStore.canAddMeter(
          currentMeterCount: meters.length,
        );
        if (!context.mounted) return;
        if (!canAdd) {
          _showMeterLimitDialog(context, meters.length);
          return;
        }
        await MeterManagementPage.showMeterDialog(context);
        if (!context.mounted) return;
        _load();
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Meter'),
    );
  }

  void _showMeterLimitDialog(BuildContext context, int currentCount) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meter limit reached'),
        content: Text(
          'Your plan covers $currentCount meter(s). '
          'Subscribe for ₹${SubscriptionConfig.basePricePerMonth}/month '
          '(includes 1 meter) and add extra meters at just '
          '₹${SubscriptionConfig.meterPricePerMonth}/month each.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          AppButton(
            label: 'View Plans',
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
