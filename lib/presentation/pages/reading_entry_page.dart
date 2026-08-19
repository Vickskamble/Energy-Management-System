import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';

class ReadingEntryPage extends StatefulWidget {
  const ReadingEntryPage({super.key});

  @override
  State<ReadingEntryPage> createState() => _ReadingEntryPageState();
}

class _ReadingEntryPageState extends State<ReadingEntryPage> {
  final _formKey = GlobalKey<FormState>();

  List<MeterModel> _meters = [];
  bool _metersLoading = true;
  bool _metersError = false;
  bool _fetchingPrevious = false;
  bool _lastSubmitWasManual = false;

  String _selectedMeter = '';
  DateTime _loggedAt = DateTime.now();
  final _currentKwhCtrl = TextEditingController();
  final _currentKvahCtrl = TextEditingController();
  final _rkvarhLagCtrl = TextEditingController();
  final _rkvarhLeadCtrl = TextEditingController();
  final _mdRecordedCtrl = TextEditingController();

  /// Previous cumulative readings fetched from the DB for the selected
  /// date/meter — read-only, never editable by the client.
  double _prevCumulativeKwh = 0;
  double _prevCumulativeKvah = 0;

  @override
  void initState() {
    super.initState();
    _loadMeters();
    context.read<MeterRepository>().addListener(_loadMeters);
    // Live consumption (difference) preview as the user types.
    _currentKwhCtrl.addListener(_onValuesChanged);
    _currentKvahCtrl.addListener(_onValuesChanged);
  }

  void _onValuesChanged() {
    if (mounted) setState(() {});
  }

  double? get _diffKwh {
    final cur = double.tryParse(_currentKwhCtrl.text.trim());
    if (cur == null) return null;
    return cur - _prevCumulativeKwh;
  }

  double? get _diffKvah {
    final cur = double.tryParse(_currentKvahCtrl.text.trim());
    if (cur == null) return null;
    return cur - _prevCumulativeKvah;
  }

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_loadMeters);
    _currentKwhCtrl.dispose();
    _currentKvahCtrl.dispose();
    _rkvarhLagCtrl.dispose();
    _rkvarhLeadCtrl.dispose();
    _mdRecordedCtrl.dispose();
    super.dispose();
  }

  double _selectedMeterContractKva() {
    for (final m in _meters) {
      if (m.name == _selectedMeter) return m.contractDemandKw;
    }
    return AppConfig.contractDemandKva;
  }

  String? get _selectedMeterSite {
    for (final m in _meters) {
      if (m.name == _selectedMeter) return m.site;
    }
    return null;
  }

  Future<void> _loadMeters() async {
    setState(() {
      _metersLoading = true;
      _metersError = false;
    });
    try {
      final repo = context.read<MeterRepository>();
      final meters = await repo.getAllMeters();
      if (!mounted) return;
      setState(() {
        _meters = meters;
        _metersLoading = false;
        if (meters.isNotEmpty) {
          _selectedMeter = meters.first.name;
          _fetchPreviousReading(_selectedMeter);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _metersLoading = false;
        _metersError = true;
      });
    }
  }

  Future<void> _fetchPreviousReading(String meterName) async {
    if (meterName.isEmpty) return;
    setState(() => _fetchingPrevious = true);
    try {
      final energyRepo = context.read<EnergyRepository>();
      // Previous = the meter's ACTUAL cumulative reading recorded BEFORE the
      // selected date — computed from the DB (stored reading, or running sum
      // for legacy rows). Never trusted from the form.
      final prev = await energyRepo.getPreviousCumulative(
        meterName,
        _loggedAt,
      );
      if (mounted) {
        setState(() {
          _prevCumulativeKwh = prev.kwh;
          _prevCumulativeKvah = prev.kvah;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingPrevious = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null) return;
    setState(() {
      _loggedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    // Date changed → the correct "previous" reading changes too.
    _fetchPreviousReading(_selectedMeter);
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _currentKwhCtrl.clear();
    _currentKvahCtrl.clear();
    _rkvarhLagCtrl.clear();
    _rkvarhLeadCtrl.clear();
    _mdRecordedCtrl.clear();
    setState(() {
      _loggedAt = DateTime.now();
      _prevCumulativeKwh = 0;
      _prevCumulativeKvah = 0;
      if (_meters.isNotEmpty) {
        _selectedMeter = _meters.first.name;
        _fetchPreviousReading(_selectedMeter);
      }
    });
  }

  String? _requiredNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
  }

  String? _optionalNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
  }

  bool get _noPreviousReading =>
      _prevCumulativeKwh <= 0 && _prevCumulativeKvah <= 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<EnergyBloc>();

    // No actual earlier reading on record (first entry, renamed meter or
    // legacy rows without stored readings) → this entry is saved as the new
    // baseline with 0 units. Alert the user and only save after they confirm.
    if (_noPreviousReading) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('No previous reading available'),
          content: const Text(
            'No earlier cumulative reading was found for this meter. '
            'This entry will be saved with 0 units (it becomes the baseline). '
            'Consumption will be calculated only when the next reading is '
            'recorded.\n\nDo you still want to save it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    _lastSubmitWasManual = true;
    bloc.add(
      SubmitManualReadingForm(
        meterName: _selectedMeter,
        currentKwh: double.parse(_currentKwhCtrl.text.trim()),
        previousKwh: _prevCumulativeKwh,
        currentKvah: double.parse(_currentKvahCtrl.text.trim()),
        previousKvah: _prevCumulativeKvah,
        rkvarhLag: double.tryParse(_rkvarhLagCtrl.text.trim()) ?? 0,
        rkvarhLead: double.tryParse(_rkvarhLeadCtrl.text.trim()) ?? 0,
        mdRecorded: double.parse(_mdRecordedCtrl.text.trim()),
        powerFactor: null,
        loggedAt: _loggedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyBloc, EnergyState>(
      listener: (context, state) {
        switch (state) {
          case EnergySuccess(:final currentPowerFactor, :final maxDemandPeak):
            // Ignore states triggered by auto-refresh / other pages —
            // success feedback belongs only to a manual form submit.
            if (!_lastSubmitWasManual) break;
            _lastSubmitWasManual = false;
            AppSnackbar.success(context, 'Reading saved successfully');
            _clearForm();
            if (currentPowerFactor < 0.95) {
              NotificationService.instance.showPfAlert(
                currentPowerFactor,
                meterName: _selectedMeter,
                site: _selectedMeterSite,
              );
            }
            final meterContract = _selectedMeterContractKva();
            if (maxDemandPeak >= meterContract * 0.95) {
              NotificationService.instance.showMdAlert(
                maxDemandPeak,
                meterContract,
                meterName: _selectedMeter,
                site: _selectedMeterSite,
              );
            }
          case EnergyValidationError _:
            _lastSubmitWasManual = false;
            AppSnackbar.warning(context, state.message);
          case EnergyOperationFailure _:
            _lastSubmitWasManual = false;
            AppSnackbar.error(context, state.message);
          default:
            break;
        }
      },
      child: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          final isLoading = state is EnergyLoading;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              AppSectionHeader(
                title: 'Manual Reading Entry',
                subtitle: 'Record energy meter readings',
              ),
              if (_metersLoading)
                const AppSkeletonCard()
              else if (_metersError)
                AppErrorState(
                  message: 'Could not load meters',
                  onRetry: _loadMeters,
                )
              else if (_meters.isEmpty)
                const AppEmptyState(
                  icon: Icons.speed_rounded,
                  title: 'No meters configured',
                  subtitle: 'Add one in Meter Management first',
                )
              else
                Form(
                  key: _formKey,
                  autovalidateMode:
                      AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enter the numbers exactly as shown on the '
                                'meter display. The app calculates consumption '
                                'automatically from the previous reading.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Meter Selection',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_selectedMeter),
                              initialValue: _selectedMeter,
                              decoration: const InputDecoration(
                                labelText: 'Meter Name',
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
                                if (v != null) {
                                  setState(() => _selectedMeter = v);
                                  _fetchPreviousReading(v);
                                }
                              },
                            ),
                            if (_fetchingPrevious)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Fetching previous reading...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reading Date & Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd/MM/yyyy, hh:mm a').format(
                                      _loggedAt,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickDateTime,
                              icon: const Icon(
                                Icons.edit_calendar_outlined,
                                size: 18,
                              ),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Energy Readings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _currentKwhCtrl,
                              label: 'Current kWh Reading',
                              hint: 'Meter display value',
                              prefixIcon: Icons.bolt,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: _requiredNumberValidator,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _currentKvahCtrl,
                              label: 'Current kVAh Reading',
                              hint: 'Meter display value',
                              prefixIcon: Icons.electrical_services,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: _requiredNumberValidator,
                            ),
                            if (_noPreviousReading) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 20,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'No previous reading found — this entry '
                                        'will be saved with 0 units. Consumption '
                                        'will be calculated when the next reading '
                                        'is recorded.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_diffKwh != null ||
                                _diffKvah != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.06,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.compare_arrows_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Consumption (Current − Previous)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(_diffKwh ?? 0).toStringAsFixed(2)} kWh · '
                                          '${(_diffKvah ?? 0).toStringAsFixed(2)} kVAh',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: (_diffKwh ?? 0) < 0 ||
                                                    (_diffKvah ?? 0) < 0
                                                ? AppColors.danger
                                                : AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.history,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Previous (auto, from DB): '
                                            '${_prevCumulativeKwh.toStringAsFixed(2)} kWh · '
                                            '${_prevCumulativeKvah.toStringAsFixed(2)} kVAh',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Power Quality',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _rkvarhLagCtrl,
                                    label: 'rkVARh (Lag)',
                                    prefixIcon: Icons.warning_outlined,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _optionalNumberValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppTextField(
                                    controller: _rkvarhLeadCtrl,
                                    label: 'rkVARh (Lead)',
                                    prefixIcon: Icons.check_circle_outline,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _optionalNumberValidator,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _mdRecordedCtrl,
                              label: 'MD Recorded (kVA) — optional',
                              hint: 'Leave blank if not available',
                              prefixIcon: Icons.trending_up,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: _optionalNumberValidator,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        label: 'Save Reading',
                        onPressed: isLoading ? null : _submit,
                        icon: Icons.save_rounded,
                        expanded: true,
                        loading: isLoading,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
