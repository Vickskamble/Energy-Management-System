import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
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
  bool _fetchingPrevious = false;
  bool _lastSubmitWasManual = false;

  String _selectedMeter = '';
  final _currentKwhCtrl = TextEditingController();
  final _previousKwhCtrl = TextEditingController();
  final _currentKvahCtrl = TextEditingController();
  final _previousKvahCtrl = TextEditingController();
  final _rkvarhLagCtrl = TextEditingController();
  final _rkvarhLeadCtrl = TextEditingController();
  final _mdRecordedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  double _selectedMeterContractKva() {
    for (final m in _meters) {
      if (m.name == _selectedMeter) return m.contractDemandKw;
    }
    return AppConstants.defaultContractDemandKva;
  }

  Future<void> _loadMeters() async {
    final repo = context.read<MeterRepository>();
    final meters = await repo.getAllMeters();
    setState(() {
      _meters = meters;
      _metersLoading = false;
      if (meters.isNotEmpty) {
        _selectedMeter = meters.first.name;
        _fetchPreviousReading(_selectedMeter);
      }
    });
  }

  Future<void> _fetchPreviousReading(String meterName) async {
    if (meterName.isEmpty) return;
    setState(() => _fetchingPrevious = true);
    try {
      final energyRepo = context.read<EnergyRepository>();
      final latest = await energyRepo.getLatestReading(meterName);
      if (latest != null && mounted) {
        _previousKwhCtrl.text = latest.kwh.toStringAsFixed(2);
        _previousKvahCtrl.text = latest.kvah.toStringAsFixed(2);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingPrevious = false);
    }
  }

  @override
  void dispose() {
    _currentKwhCtrl.dispose();
    _previousKwhCtrl.dispose();
    _currentKvahCtrl.dispose();
    _previousKvahCtrl.dispose();
    _rkvarhLagCtrl.dispose();
    _rkvarhLeadCtrl.dispose();
    _mdRecordedCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _currentKwhCtrl.clear();
    _previousKwhCtrl.clear();
    _currentKvahCtrl.clear();
    _previousKvahCtrl.clear();
    _rkvarhLagCtrl.clear();
    _rkvarhLeadCtrl.clear();
    _mdRecordedCtrl.clear();
    setState(() {
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _lastSubmitWasManual = true;
    context.read<EnergyBloc>().add(
      SubmitManualReadingForm(
        meterName: _selectedMeter,
        currentKwh: double.parse(_currentKwhCtrl.text.trim()),
        previousKwh: double.parse(_previousKwhCtrl.text.trim()),
        currentKvah: double.parse(_currentKvahCtrl.text.trim()),
        previousKvah: double.parse(_previousKvahCtrl.text.trim()),
        rkvarhLag: double.tryParse(_rkvarhLagCtrl.text.trim()) ?? 0,
        rkvarhLead: double.tryParse(_rkvarhLeadCtrl.text.trim()) ?? 0,
        mdRecorded: double.parse(_mdRecordedCtrl.text.trim()),
        loggedAt: DateTime.now(),
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
              NotificationService.instance.showPfAlert(currentPowerFactor);
            }
            final meterContract = _selectedMeterContractKva();
            if (maxDemandPeak >= meterContract * 0.95) {
              NotificationService.instance.showMdAlert(
                maxDemandPeak,
                meterContract,
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
              else if (_meters.isEmpty)
                const AppEmptyState(
                  icon: Icons.speed_rounded,
                  title: 'No meters configured',
                  subtitle: 'Add one in Meter Management first',
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _currentKwhCtrl,
                                    label: 'Current kWh',
                                    prefixIcon: Icons.bolt,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _requiredNumberValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppTextField(
                                    controller: _previousKwhCtrl,
                                    label: 'Previous kWh',
                                    hint: 'Auto-fetched',
                                    prefixIcon: Icons.history,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _requiredNumberValidator,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _currentKvahCtrl,
                                    label: 'Current kVAh',
                                    prefixIcon: Icons.electrical_services,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _requiredNumberValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppTextField(
                                    controller: _previousKvahCtrl,
                                    label: 'Previous kVAh',
                                    hint: 'Auto-fetched',
                                    prefixIcon: Icons.history,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: _requiredNumberValidator,
                                  ),
                                ),
                              ],
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
                              label: 'MD Recorded (kVA)',
                              prefixIcon: Icons.trending_up,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
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
