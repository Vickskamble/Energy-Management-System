import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_config.dart';
import '../../core/network/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/backup_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../data/repositories/meter_repository.dart';
import '../auth_bloc/auth_bloc.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;

  const SettingsScreen({super.key, this.isDark = false, this.onToggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _tariffCtrl = TextEditingController();
  final _demandCtrl = TextEditingController();
  final _facCtrl = TextEditingController();
  final _wheelingCtrl = TextEditingController();
  final _dutyCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _subsidyCtrl = TextEditingController();
  final _tariffFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tariffCtrl.text = AppConfig.tariffPerUnit.toStringAsFixed(2);
    _demandCtrl.text = AppConfig.demandChargePerKva.toStringAsFixed(2);
    _facCtrl.text = AppConfig.facRatePerUnit.toStringAsFixed(2);
    _wheelingCtrl.text = AppConfig.wheelingChargePerUnit.toStringAsFixed(2);
    _dutyCtrl.text = AppConfig.electricityDutyPercent.toStringAsFixed(2);
    _taxCtrl.text = AppConfig.taxPercent.toStringAsFixed(2);
    _subsidyCtrl.text = AppConfig.subsidyPercent.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _tariffCtrl.dispose();
    _demandCtrl.dispose();
    _facCtrl.dispose();
    _wheelingCtrl.dispose();
    _dutyCtrl.dispose();
    _taxCtrl.dispose();
    _subsidyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Account', icon: Icon(Icons.person_outline, size: 18)),
            Tab(
              text: 'Appearance',
              icon: Icon(Icons.palette_outlined, size: 18),
            ),
            Tab(
              text: 'Billing',
              icon: Icon(Icons.receipt_long_outlined, size: 18),
            ),
            Tab(text: 'System', icon: Icon(Icons.memory_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAccount(),
          _buildAppearance(),
          _buildBilling(),
          _buildSystem(),
        ],
      ),
    );
  }

  Widget _buildAccount() {
    final authState = context.watch<AuthBloc>().state;
    final email = authState is AppAuthAuthenticated
        ? authState.email
        : 'user@powerems.com';
    final name = authState is AppAuthAuthenticated
        ? authState.email.split('@').first
        : 'User';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Account',
          subtitle: 'Your account information',
        ),
        AppCard(
          child: Column(
            children: [
              _accountRow(Icons.person_outline, 'Full Name', name),
              const Divider(),
              _accountRow(Icons.email_outlined, 'Email', email),
              const Divider(),
              _accountRow(
                Icons.business_outlined,
                'Organization',
                'PowerEMS Inc.',
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Sign out',
                  style: TextStyle(fontSize: 14, color: AppColors.danger),
                ),
                trailing: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            context.read<AuthBloc>().add(
                              const AppAuthLogoutRequested(),
                            );
                          },
                          child: const Text(
                            'Sign out',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearance() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Appearance',
          subtitle: 'Customize the look and feel',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  widget.isDark ? 'Dark theme active' : 'Light theme active',
                  style: const TextStyle(fontSize: 12),
                ),
                value: widget.isDark,
                onChanged: (_) => widget.onToggleTheme?.call(),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _rateValidator(String? v, {bool mustBePositive = false}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final val = double.tryParse(v.trim());
    if (val == null) return 'Invalid number';
    if (mustBePositive && val <= 0) return 'Must be positive';
    if (val < 0) return 'Cannot be negative';
    return null;
  }

  Widget _rateField(
    TextEditingController controller,
    String label,
    String hint, {
    bool mustBePositive = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
      validator: (v) => _rateValidator(v, mustBePositive: mustBePositive),
    );
  }

  Future<void> _saveTariff() async {
    if (!_tariffFormKey.currentState!.validate()) return;
    try {
      await TariffStore.saveAll(
        tariffPerUnit: double.parse(_tariffCtrl.text.trim()),
        demandChargePerKva: double.parse(_demandCtrl.text.trim()),
        facRatePerUnit: double.parse(_facCtrl.text.trim()),
        wheelingChargePerUnit: double.parse(_wheelingCtrl.text.trim()),
        electricityDutyPercent: double.parse(_dutyCtrl.text.trim()),
        taxPercent: double.parse(_taxCtrl.text.trim()),
        subsidyPercent: double.parse(_subsidyCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tariff updated — bills will recalculate'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save tariff: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _resetTariff() async {
    AppConfig.reset();
    _tariffCtrl.text = AppConfig.tariffPerUnit.toStringAsFixed(2);
    _demandCtrl.text = AppConfig.demandChargePerKva.toStringAsFixed(2);
    _facCtrl.text = AppConfig.facRatePerUnit.toStringAsFixed(2);
    _wheelingCtrl.text = AppConfig.wheelingChargePerUnit.toStringAsFixed(2);
    _dutyCtrl.text = AppConfig.electricityDutyPercent.toStringAsFixed(2);
    _taxCtrl.text = AppConfig.taxPercent.toStringAsFixed(2);
    _subsidyCtrl.text = AppConfig.subsidyPercent.toStringAsFixed(2);
    await TariffStore.saveAll(
      tariffPerUnit: AppConfig.tariffPerUnit,
      demandChargePerKva: AppConfig.demandChargePerKva,
      facRatePerUnit: AppConfig.facRatePerUnit,
      wheelingChargePerUnit: AppConfig.wheelingChargePerUnit,
      electricityDutyPercent: AppConfig.electricityDutyPercent,
      taxPercent: AppConfig.taxPercent,
      subsidyPercent: AppConfig.subsidyPercent,
    );
  }

  Widget _buildBilling() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Billing',
          subtitle: 'Tariff configuration used for all bill estimates',
        ),
        AppCard(
          child: Form(
            key: _tariffFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Energy charges',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _rateField(
                  _tariffCtrl,
                  'Energy Tariff (₹ per kWh)',
                  'e.g. 8.68',
                  mustBePositive: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Demand & ancillary charges',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _rateField(
                        _demandCtrl,
                        'Demand (₹ per kVA)',
                        'e.g. 320',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _facCtrl,
                        'FAC (₹ per unit)',
                        'e.g. 0.85',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _rateField(
                        _wheelingCtrl,
                        'Wheeling (₹ per unit)',
                        'e.g. 0.65',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _dutyCtrl,
                        'Electricity Duty (%)',
                        'e.g. 5.0',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _rateField(
                        _taxCtrl,
                        'Tax (%)',
                        'e.g. 0.5',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _subsidyCtrl,
                        'Subsidy (%)',
                        '0 = none',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Save Tariff',
                  icon: Icons.save_outlined,
                  onPressed: _saveTariff,
                  expanded: true,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _resetTariff,
                  child: const Text('Reset to defaults'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystem() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'System',
          subtitle: 'System information and configuration',
        ),
        AppCard(
          child: Column(
            children: [
              _accountRow(Icons.info_outline, 'App Version', '1.0.0'),
              const Divider(),
              _accountRow(
                Icons.cloud_outlined,
                'Supabase',
                SupabaseClientManager.isInitialized ? 'Connected' : 'Not configured',
              ),
              const Divider(),
              _accountRow(
                Icons.auto_awesome_outlined,
                'Analysis Engine',
                'Rule-based',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'Backup & Restore',
          subtitle: 'Export or import all local readings, meters and settings',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppButton(
                label: 'Export Backup',
                icon: Icons.upload_file_rounded,
                expanded: true,
                onPressed: _exportBackup,
              ),
              const SizedBox(height: 8),
              AppButtonOutline(
                label: 'Restore From File',
                icon: Icons.download_rounded,
                expanded: true,
                onPressed: _confirmRestore,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup() async {
    try {
      await BackupService.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exported'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore data?'),
        content: const Text(
          'This replaces ALL current readings, meters and settings with the '
          'contents of the backup file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await BackupService.restoreBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${result.recordCount} record(s) from '
            '${result.restoredDbs.join(', ')}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      context.read<MeterRepository>().refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _accountRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
