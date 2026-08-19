import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/config/tariff_presets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/backup_service.dart';
import '../../core/utils/data_reset_service.dart';
import '../../core/utils/validation_rules.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../widgets/app_tour.dart';
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
  final _mdCtrl = TextEditingController();
  final _icrRateCtrl = TextEditingController();
  final _icrUnitsCtrl = TextEditingController();
  final _lfCtrl = TextEditingController();
  final _ppdCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  final _arrearsCtrl = TextEditingController();
  final _precedingCtrls = List.generate(11, (_) => TextEditingController());
  final _tariffFormKey = GlobalKey<FormState>();

  bool _roundToTen = AppConstants.roundToTen;
  bool _billOnKvah = AppConstants.billOnKvah;

  /// Labels for the preceding 11 months (oldest → most recent).
  List<String> get _precedingMonthLabels {
    final now = DateTime.now();
    return List.generate(11, (i) {
      final d = DateTime(now.year, now.month - (10 - i));
      return DateFormat('MMM yy').format(d);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _category = AppConfig.tariffCategory;
    _version = AppConfig.tariffVersion;
    _tariffCtrl.text = AppConfig.tariffPerUnit.toStringAsFixed(2);
    _demandCtrl.text = AppConfig.demandChargePerKva.toStringAsFixed(2);
    _facCtrl.text = AppConfig.facRatePerUnit.toStringAsFixed(2);
    _wheelingCtrl.text = AppConfig.wheelingChargePerUnit.toStringAsFixed(2);
    _dutyCtrl.text = AppConfig.dutyPercent.toStringAsFixed(0);
    _taxCtrl.text = AppConfig.taxPercent.toStringAsFixed(2);
    _subsidyCtrl.text = AppConfig.subsidyPercent.toStringAsFixed(2);
    _mdCtrl.text = AppConfig.contractDemandKva.toStringAsFixed(0);
    _icrRateCtrl.text = AppConfig.icrRatePerUnit.toStringAsFixed(2);
    _icrUnitsCtrl.text = AppConfig.icrLastYearUnits == 0
        ? ''
        : AppConfig.icrLastYearUnits.toStringAsFixed(0);
    _lfCtrl.text = AppConfig.lfIncentivePercent.toStringAsFixed(1);
    _ppdCtrl.text = AppConfig.ppdPercent.toStringAsFixed(1);
    _bulkCtrl.text = AppConfig.bulkRebatePercent.toStringAsFixed(1);
    _arrearsCtrl.text = AppConfig.arrearsDpcAmount == 0
        ? ''
        : AppConfig.arrearsDpcAmount.toStringAsFixed(0);
    _roundToTen = AppConfig.roundToTen;
    _billOnKvah = AppConfig.billOnKvah;
    final preceding = AppConfig.precedingDemandKva;
    for (var i = 0; i < 11; i++) {
      if (preceding[i] > 0) {
        _precedingCtrls[i].text = preceding[i].toStringAsFixed(2);
      }
    }
    _mdCtrl.addListener(_onMdChanged);
  }

  void _onMdChanged() {
    if (mounted) setState(() {});
  }

  late TariffCategory _category;
  late TariffVersion _version;

  /// Applies the official preset for [category] × [version] into every
  /// tariff field. Individual fields remain editable afterwards.
  void _applyPreset(TariffCategory category, TariffVersion version) {
    final preset = AppConfig.applyTariffPreset(category, version);
    setState(() {
      _category = category;
      _version = version;
      _tariffCtrl.text = preset.energyRate.toStringAsFixed(2);
      _demandCtrl.text = preset.demandRate.toStringAsFixed(0);
      _wheelingCtrl.text = preset.wheelingRate.toStringAsFixed(2);
      _dutyCtrl.text = preset.dutyPercent.toStringAsFixed(0);
      _mdCtrl.text = preset.defaultContractDemand.toStringAsFixed(0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          preset.isSlabBased
              ? '${preset.category.label} ${preset.version.label} applied — '
                  'slab-wise energy charges (auto)'
              : '${preset.category.label} ${preset.version.label} applied',
        ),
        backgroundColor: Colors.green,
      ),
    );
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
    _icrRateCtrl.dispose();
    _icrUnitsCtrl.dispose();
    _lfCtrl.dispose();
    _ppdCtrl.dispose();
    _bulkCtrl.dispose();
    _arrearsCtrl.dispose();
    _mdCtrl.removeListener(_onMdChanged);
    _mdCtrl.dispose();
    for (final c in _precedingCtrls) {
      c.dispose();
    }
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
    bool optional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
      validator: optional
          ? (v) {
              if (v == null || v.trim().isEmpty) return null;
              return _rateValidator(v, mustBePositive: mustBePositive);
            }
          : (v) => _rateValidator(v, mustBePositive: mustBePositive),
    );
  }

  Future<void> _saveTariff() async {
    if (!_tariffFormKey.currentState!.validate()) return;
    for (final c in _precedingCtrls) {
      final v = c.text.trim();
      if (v.isNotEmpty && double.tryParse(v) == null) return;
    }
    try {
      AppConfig.dutyPercent = double.parse(_dutyCtrl.text.trim());
      AppConfig.taxPercent = double.parse(_taxCtrl.text.trim());
      AppConfig.icrRatePerUnit = double.parse(_icrRateCtrl.text.trim());
      AppConfig.icrLastYearUnits = double.tryParse(_icrUnitsCtrl.text.trim()) ?? 0;
      AppConfig.lfIncentivePercent = double.parse(_lfCtrl.text.trim());
      AppConfig.ppdPercent = double.parse(_ppdCtrl.text.trim());
      AppConfig.bulkRebatePercent = double.parse(_bulkCtrl.text.trim());
      AppConfig.arrearsDpcAmount = double.tryParse(_arrearsCtrl.text.trim()) ?? 0;
      AppConfig.roundToTen = _roundToTen;
      AppConfig.billOnKvah = _billOnKvah;
      await TariffStore.saveAll(
        tariffPerUnit: double.parse(_tariffCtrl.text.trim()),
        demandChargePerKva: double.parse(_demandCtrl.text.trim()),
        facRatePerUnit: double.parse(_facCtrl.text.trim()),
        wheelingChargePerUnit: double.parse(_wheelingCtrl.text.trim()),
        electricityDutyPerUnit: AppConfig.electricityDutyPerUnit,
        taxPerUnit: double.parse(_taxCtrl.text.trim()),
        subsidyPercent: double.parse(_subsidyCtrl.text.trim()),
        contractDemandKva: double.parse(_mdCtrl.text.trim()),
        precedingDemandKva: [
          for (final c in _precedingCtrls)
            double.tryParse(c.text.trim()) ?? 0,
        ],
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
    _applyPreset(TariffCategory.htIndustrial, TariffVersion.fy2627);
    _facCtrl.text = AppConfig.facRatePerUnit.toStringAsFixed(2);
    AppConfig.taxPercent = AppConstants.taxPercent;
    AppConfig.icrRatePerUnit = AppConstants.icrRatePerUnit;
    AppConfig.icrLastYearUnits = 0;
    AppConfig.lfIncentivePercent = AppConstants.lfIncentivePercent;
    AppConfig.ppdPercent = AppConstants.ppdPercent;
    AppConfig.bulkRebatePercent = AppConstants.bulkRebatePercent;
    AppConfig.arrearsDpcAmount = AppConstants.arrearsDpcAmount;
    AppConfig.roundToTen = AppConstants.roundToTen;
    AppConfig.billOnKvah = AppConstants.billOnKvah;
    AppConfig.facRatesByMonth = {};
    setState(() {
      _taxCtrl.text = AppConfig.taxPercent.toStringAsFixed(2);
      _icrRateCtrl.text = AppConfig.icrRatePerUnit.toStringAsFixed(2);
      _icrUnitsCtrl.text = '';
      _lfCtrl.text = AppConfig.lfIncentivePercent.toStringAsFixed(1);
      _ppdCtrl.text = AppConfig.ppdPercent.toStringAsFixed(1);
      _bulkCtrl.text = AppConfig.bulkRebatePercent.toStringAsFixed(1);
      _arrearsCtrl.text = '';
      _roundToTen = AppConfig.roundToTen;
      _billOnKvah = AppConfig.billOnKvah;
      _subsidyCtrl.text = AppConfig.subsidyPercent.toStringAsFixed(2);
    });
    for (final c in _precedingCtrls) {
      c.clear();
    }
    await TariffStore.saveAll(
      tariffPerUnit: AppConfig.tariffPerUnit,
      demandChargePerKva: AppConfig.demandChargePerKva,
      facRatePerUnit: AppConfig.facRatePerUnit,
      wheelingChargePerUnit: AppConfig.wheelingChargePerUnit,
      electricityDutyPerUnit: AppConfig.electricityDutyPerUnit,
      taxPerUnit: AppConfig.taxPerUnit,
      subsidyPercent: AppConfig.subsidyPercent,
      contractDemandKva: AppConfig.contractDemandKva,
      precedingDemandKva: AppConfig.precedingDemandKva,
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
                  'Tariff category & year',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TariffCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category (MERC)',
                    isDense: true,
                  ),
                  items: [
                    for (final c in TariffCategory.values)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _applyPreset(v, _version);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TariffVersion>(
                  initialValue: _version,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tariff Year',
                    isDense: true,
                  ),
                  items: [
                    for (final v in TariffVersion.values)
                      DropdownMenuItem(
                        value: v,
                        child: Text(v.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _applyPreset(_category, v);
                  },
                ),
                const SizedBox(height: 16),
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
                  'e.g. 6.40',
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
                        'e.g. 650',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _facCtrl,
                        'FAC (₹ per unit)',
                        'e.g. 0.30',
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
                        'e.g. 0.61',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _dutyCtrl,
                        'Elec. Duty (% of EC)',
                        '0 = exempt (HT)',
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
                        'Tax (% of EC)',
                        'e.g. 1.25',
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
                Text(
                  'MD (contract demand) & ratchet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _rateField(
                        _mdCtrl,
                        'MD (kVA)',
                        'e.g. 201',
                        mustBePositive: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _md75PercentTile()),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Billing demand = max(recorded MD, highest demand of the '
                  'preceding 11 months). 75% of MD is only a REFERENCE level '
                  'to stay above — it is never used in the bill. Recorded '
                  'monthly highs enter automatically and stay in the window '
                  'for the next 11 months until a higher reading breaks them. '
                  'Enter demands from your past bills only for months with no '
                  'app data — empty fields are ignored.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                ExpansionTile(
                  title: const Text('Advanced tariff settings'),
                  subtitle: const Text(
                    'Only adjust these if you are familiar with tariff mechanics',
                  ),
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        for (var i = 0; i < 11; i += 2) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _rateField(
                          _precedingCtrls[i],
                          'M-${11 - i} (${_precedingMonthLabels[i]})',
                          'kVA if known',
                          optional: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (i + 1 < 11)
                        Expanded(
                          child: _rateField(
                            _precedingCtrls[i + 1],
                            'M-${10 - i} (${_precedingMonthLabels[i + 1]})',
                            'kVA if known',
                            optional: true,
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                  if (i + 2 < 11) const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Text(
                  'Rebates & adjustments',
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
                        _icrRateCtrl,
                        'ICR (₹/unit)',
                        '0 = off',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _icrUnitsCtrl,
                        'Last-yr same month units',
                        'kVAh if known',
                        optional: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Incremental Consumption Rebate — applies ₹/unit on the '
                  'consumption growth when it exceeds last year\u2019s same '
                  'month by ≥ 10%.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _rateField(
                        _lfCtrl,
                        'LF incentive (%)',
                        '0 = off',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _ppdCtrl,
                        'PPD (%)',
                        'e.g. 2.0',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _rateField(
                        _bulkCtrl,
                        'Bulk rebate (%)',
                        '0 = off',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _rateField(
                        _arrearsCtrl,
                        'Arrears/DPC (₹)',
                        '0 = none',
                        optional: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Round bill to nearest ₹10',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _roundToTen,
                  onChanged: (v) => setState(() => _roundToTen = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text(
                    'Bill on kVAh (PF-adjusted)',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'On = kVAh (official), Off = kWh',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _billOnKvah,
                  onChanged: (v) => setState(() => _billOnKvah = v),
                  contentPadding: EdgeInsets.zero,
                ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saving updates the tariff used for all future bill estimates.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
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

  /// Auto-computed 75% of MD — shown but intentionally non-editable.
  Widget _md75PercentTile() {
    final md = double.tryParse(_mdCtrl.text.trim()) ?? 0;
    final floor = md * AppConstants.billingDemandFloorPercent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '75% of MD (auto)',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${floor.toStringAsFixed(1)} kVA',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
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
              _accountRow(Icons.info_outline, 'App Version', AppConfig.appVersion),
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
          title: 'Help & Support',
          subtitle: 'Guided tour, user guide and support contact',
        ),
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.tour_rounded),
                title: const Text('Show App Tour'),
                subtitle: const Text('Replay the guided walkthrough'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: TourLauncher.start,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Help & User Guide'),
                subtitle: const Text('Feature guide and expert support'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showHelpDialog(context),
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
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'Danger Zone',
          subtitle:
              'Reset data (keep account) or delete the account permanently',
        ),
        AppCard(
          child: Column(
            children: [
              AppButton(
                label: 'Reset All Data',
                icon: Icons.delete_forever_outlined,
                color: AppColors.danger,
                expanded: true,
                onPressed: _confirmResetAll,
              ),
              const SizedBox(height: 8),
              AppButtonOutline(
                label: 'Delete Account',
                icon: Icons.person_remove_outlined,
                expanded: true,
                onPressed: _confirmDeleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup() async {
    final encrypt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export backup'),
        content: const Text(
          'You can encrypt the backup with a passphrase for safety, or export '
          'it without a password. Keep an unencrypted file secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No password'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encrypt'),
          ),
        ],
      ),
    );
    if (encrypt == null) return;

    String? passphrase;
    if (encrypt) {
      passphrase = await _askPassphrase(
        title: 'Set backup passphrase',
        message:
            'Choose a passphrase for the backup. If you lose it, the backup '
            'cannot be recovered.\n'
            'Min ${ValidationRules.minPasswordLength} characters, '
            'at least one letter and one number.',
      );
      if (passphrase == null) return;
    }

    try {
      await BackupService.exportBackup(passphrase: passphrase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              passphrase == null
                  ? 'Backup exported (unencrypted)'
                  : 'Encrypted backup exported',
            ),
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
      ({int recordCount, List<String> restoredDbs}) result;
      try {
        result = await BackupService.restoreBackup();
      } on BackupEncryptionRequired {
        final passphrase = await _askPassphrase(
          title: 'Enter backup passphrase',
          message:
              'This backup is encrypted. Enter the passphrase that was used '
              'when the backup was created.',
        );
        if (passphrase == null) return;
        result = await BackupService.restoreBackup(passphrase: passphrase);
      }
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

  /// Prompts for a backup passphrase. Returns null when cancelled.
  /// Validates the same password policy as account registration
  /// (min length + letter + digit) — see ValidationRules.
  Future<String?> _askPassphrase({
    required String title,
    required String message,
  }) async {
    final ctrl = TextEditingController();
    var obscure = true;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final error = ValidationRules.validatePassword(ctrl.text);
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Passphrase too weak — $error'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, ctrl.text);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return passphrase;
  }

  Future<void> _confirmResetAll() async {    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently deletes ALL readings, meters and settings — '
          'locally AND from Supabase (this account). '
          'It cannot be undone. Export a backup first if you want to keep '
          'anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Delete Everything',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DataResetService.resetAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data deleted — fresh start'),
          backgroundColor: Colors.green,
        ),
      );
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
      context.read<MeterRepository>().refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account AND ALL your data '
          '(readings, meters, settings, backups on the server, sessions) '
          'from Supabase. It cannot be undone. '
          'Export a backup first if you want to keep anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Delete Account',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DataResetService.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted — you have been signed out'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
      context.read<AuthBloc>().add(const AppAuthLogoutRequested());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deletion failed: $e'),
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
