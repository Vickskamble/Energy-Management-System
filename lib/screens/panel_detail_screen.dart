import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ems_provider.dart';
import '../models/panel.dart';
import 'meter_detail_screen.dart';

class PanelDetailScreen extends StatefulWidget {
  final Panel panel;
  const PanelDetailScreen({super.key, required this.panel});

  @override
  State<PanelDetailScreen> createState() => _PanelDetailScreenState();
}

class _PanelDetailScreenState extends State<PanelDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmsProvider>().selectPanel(widget.panel);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.panel.name)),
      body: Consumer<EmsProvider>(
        builder: (_, provider, _) {
          if (provider.meters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speed, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No meters in this panel',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddMeterDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Meter'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Panel Info',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (widget.panel.panelType != null)
                        Text('Type: ${widget.panel.panelType}'),
                      Text('${provider.meters.length} meter(s) installed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Meters',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...provider.meters.map((meter) => _buildMeterCard(context, meter)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMeterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Meter'),
      ),
    );
  }

  Widget _buildMeterCard(BuildContext context, dynamic meter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: const Icon(Icons.speed, color: Colors.green),
        ),
        title: Text('Meter ${meter.meterNumber}'),
        subtitle: Text(meter.meterType ?? 'Standard'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<EmsProvider>(),
                child: MeterDetailScreen(meter: meter),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMeterDialog(BuildContext context) {
    final numberController = TextEditingController();
    final typeController = TextEditingController();
    final ctRatioController = TextEditingController();
    final ptRatioController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Meter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Meter Number',
                  hintText: 'e.g., M-001',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Meter Type (optional)',
                  hintText: 'e.g., KWh, KVArh',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctRatioController,
                decoration: const InputDecoration(
                  labelText: 'CT Ratio (optional)',
                  hintText: 'e.g., 2000/5',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ptRatioController,
                decoration: const InputDecoration(
                  labelText: 'PT Ratio (optional)',
                  hintText: 'e.g., 11000/110',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (numberController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await context.read<EmsProvider>().createMeter(
                    widget.panel.id,
                    numberController.text.trim(),
                    meterType: typeController.text.trim().isEmpty
                        ? null
                        : typeController.text.trim(),
                    ctRatio: double.tryParse(ctRatioController.text),
                    ptRatio: double.tryParse(ptRatioController.text),
                  );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
