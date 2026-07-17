import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/notification_service.dart';
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
      // No previous reading — leave fields blank
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<EnergyBloc>().add(SubmitManualReadingForm(
          meterName: _selectedMeter,
          currentKwh: double.parse(_currentKwhCtrl.text.trim()),
          previousKwh: double.parse(_previousKwhCtrl.text.trim()),
          currentKvah: double.parse(_currentKvahCtrl.text.trim()),
          previousKvah: double.parse(_previousKvahCtrl.text.trim()),
          rkvarhLag: double.tryParse(_rkvarhLagCtrl.text.trim()) ?? 0,
          rkvarhLead: double.tryParse(_rkvarhLeadCtrl.text.trim()) ?? 0,
          mdRecorded: double.parse(_mdRecordedCtrl.text.trim()),
          loggedAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyBloc, EnergyState>(
      listener: (context, state) {
        switch (state) {
          case EnergySuccess(
              :final currentPowerFactor,
              :final maxDemandPeak,
            ):
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reading saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _clearForm();
            if (currentPowerFactor < 0.95) {
              NotificationService.instance.showPfAlert(currentPowerFactor);
            }
            if (maxDemandPeak >= 380) {
              NotificationService.instance.showMdAlert(maxDemandPeak, 400);
            }
          case EnergyValidationError _:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.orange,
              ),
            );
          case EnergyOperationFailure _:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          default:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Manual Reading Entry')),
        body: BlocBuilder<EnergyBloc, EnergyState>(
          builder: (context, state) {
            final isLoading = state is EnergyLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_metersLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_meters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No meters configured. Add one in Settings.'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMeter,
                        decoration: const InputDecoration(
                          labelText: 'Meter Name',
                          border: OutlineInputBorder(),
                        ),
                        items: _meters
                            .map((m) => DropdownMenuItem(value: m.name, child: Text(m.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedMeter = v);
                            _fetchPreviousReading(v);
                          }
                        },
                      ),
                    const SizedBox(height: 16),

                    if (_fetchingPrevious)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Fetching previous reading...',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentKwhCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Current kWh',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _previousKwhCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Previous kWh',
                              hintText: 'Auto-fetched',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentKvahCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Current kVAh',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _previousKvahCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Previous kVAh',
                              hintText: 'Auto-fetched',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rkvarhLagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'rkVARh (Lag)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rkvarhLeadCtrl,
                            decoration: const InputDecoration(
                              labelText: 'rkVARh (Lead)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _mdRecordedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'MD Recorded (kW)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(isLoading ? 'Saving...' : 'Save Reading'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
