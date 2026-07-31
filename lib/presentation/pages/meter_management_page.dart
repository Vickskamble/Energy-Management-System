import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/meter_repository.dart';

class MeterManagementPage extends StatelessWidget {
  const MeterManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MeterList();
  }

  static Future<void> _showMeterDialog(BuildContext context, {MeterModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final demandCtrl = TextEditingController(
      text: existing?.contractDemandKw.toStringAsFixed(0) ?? '400',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Meter' : 'Add Meter'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameCtrl, label: 'Meter Name', prefixIcon: Icons.speed_rounded,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              AppTextField(controller: locationCtrl, label: 'Location (optional)', prefixIcon: Icons.location_on_outlined),
              const SizedBox(height: 12),
              AppTextField(controller: demandCtrl, label: 'Contract Demand (kW)', prefixIcon: Icons.trending_up,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          AppButton(
            label: 'Save',
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final repo = context.read<MeterRepository>();
              final meter = existing != null
                  ? MeterModel(
                      id: existing.id,
                      name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                      contractDemandKw: double.parse(demandCtrl.text.trim()),
                      isActive: existing.isActive,
                    )
                  : MeterModel.create(
                      name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                      contractDemandKw: double.parse(demandCtrl.text.trim()),
                    );
              if (existing != null) {
                repo.updateMeter(meter);
              } else {
                repo.saveMeter(meter);
              }
              Navigator.pop(ctx, true);
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<MeterRepository>();
    final meters = await repo.getAllMeters();
    setState(() {
      _meters = meters;
      _loading = false;
    });
  }

  List<MeterModel> get _filteredMeters {
    if (_searchQuery.isEmpty) return _meters;
    return _meters.where((m) =>
        m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (m.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_meters.isEmpty) {
      return const AppEmptyState(
        icon: Icons.speed_rounded,
        title: 'No meters configured',
        subtitle: 'Tap + to add your first meter',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, 0),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: _filteredMeters.length,
              itemBuilder: (context, index) {
                final meter = _filteredMeters[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: (meter.isActive ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(meter.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: meter.isActive ? AppColors.success : AppColors.textSecondary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meter.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${meter.contractDemandKw.toStringAsFixed(0)} kW${meter.location != null ? ' — ${meter.location}' : ''}',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () async {
                            await MeterManagementPage._showMeterDialog(context, existing: meter);
                            _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () async {
                            final repo = context.read<MeterRepository>();
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
    );
  }
}
