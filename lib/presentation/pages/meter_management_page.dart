import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/meter_repository.dart';

class MeterManagementPage extends StatelessWidget {
  const MeterManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Meters')),
      body: _MeterList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMeterDialog(context),
        child: const Icon(Icons.add),
      ),
    );
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
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Meter' : 'Add Meter'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Meter Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: demandCtrl,
                decoration: const InputDecoration(labelText: 'Contract Demand (kW)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
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
            child: const Text('Save'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_meters.isEmpty) {
      return const Center(child: Text('No meters configured yet. Tap + to add one.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _meters.length,
        itemBuilder: (context, index) {
          final meter = _meters[index];
          return ListTile(
            leading: Icon(meter.isActive ? Icons.check_circle : Icons.cancel, color: meter.isActive ? Colors.green : Colors.grey),
            title: Text(meter.name),
            subtitle: Text('${meter.contractDemandKw.toStringAsFixed(0)} kW${meter.location != null ? ' — ${meter.location}' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    await MeterManagementPage._showMeterDialog(context, existing: meter);
                    _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () async {
                    final repo = context.read<MeterRepository>();
                    await repo.deleteMeter(meter.id);
                    _load();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
