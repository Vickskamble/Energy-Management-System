import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/ems_provider.dart';
import '../models/meter.dart';
import '../models/reading.dart';

class MeterDetailScreen extends StatefulWidget {
  final Meter meter;
  const MeterDetailScreen({super.key, required this.meter});

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmsProvider>().selectMeter(widget.meter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meter ${widget.meter.meterNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddReadingSheet(context),
          ),
        ],
      ),
      body: Consumer<EmsProvider>(
        builder: (_, provider, _) {
          if (provider.readings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No readings recorded',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tap + to add the first reading',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadReadings(widget.meter.id);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMeterInfoCard(context, widget.meter),
                const SizedBox(height: 16),
                _buildLatestReadingCard(context, provider.readings.first),
                const SizedBox(height: 16),
                _buildTrendChart(context, provider.readings),
                const SizedBox(height: 16),
                Text('Reading History',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...provider.readings.take(30).map(
                  (r) => _buildReadingRow(context, r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeterInfoCard(BuildContext context, Meter meter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meter Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (meter.meterType != null)
              _infoRow('Type', meter.meterType!),
            if (meter.ctRatio != null)
              _infoRow('CT Ratio', '${meter.ctRatio}'),
            if (meter.ptRatio != null)
              _infoRow('PT Ratio', '${meter.ptRatio}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey[600])),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildLatestReadingCard(BuildContext context, Reading r) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Latest Reading: ${DateFormat('dd MMM yyyy').format(r.readingDate)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _paramBox('kWh', r.kwhImport?.toStringAsFixed(1) ?? '-'),
                _paramBox('kVArh', r.kvahImport?.toStringAsFixed(1) ?? '-'),
                _paramBox('kW', r.kwDemand?.toStringAsFixed(1) ?? '-'),
                _paramBox('PF', r.powerFactor?.toStringAsFixed(2) ?? '-'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _paramBox('V', r.voltageLNAvg?.toStringAsFixed(0) ?? '-'),
                _paramBox('A', r.currentAvg?.toStringAsFixed(0) ?? '-'),
                _paramBox('Hz', r.frequency?.toStringAsFixed(1) ?? '-'),
                _paramBox('THD', '${r.thd?.toStringAsFixed(1) ?? '-'}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paramBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildTrendChart(BuildContext context, List<Reading> readings) {
    final chartData = readings.reversed.take(30).toList();
    if (chartData.length < 2) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('kW Demand Trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(chartData.length, (i) {
                        final val = chartData[i].kwDemand ?? 0;
                        return FlSpot(i.toDouble(), val);
                      }),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(30),
                      ),
                    ),
                    if (chartData.any((r) => r.powerFactor != null))
                      LineChartBarData(
                        spots: List.generate(chartData.length, (i) {
                          final val = chartData[i].powerFactor ?? 0;
                          return FlSpot(i.toDouble(), val);
                        }),
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Theme.of(context).colorScheme.primary, 'kW'),
                if (chartData.any((r) => r.powerFactor != null))
                  const SizedBox(width: 16),
                if (chartData.any((r) => r.powerFactor != null))
                  _legendDot(Colors.orange, 'PF'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
        )),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildReadingRow(BuildContext context, Reading r) {
    final dateStr = DateFormat('dd MMM yy').format(r.readingDate);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        title: Text(dateStr),
        subtitle: Text(
          'kWh: ${r.kwhImport?.toStringAsFixed(0) ?? '-'}  |  '
          'kW: ${r.kwDemand?.toStringAsFixed(1) ?? '-'}  |  '
          'PF: ${r.powerFactor?.toStringAsFixed(2) ?? '-'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () {
            // TODO: delete reading
          },
        ),
      ),
    );
  }

  void _showAddReadingSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final kwhImpCtrl = TextEditingController();
    final kwhExpCtrl = TextEditingController();
    final kvahImpCtrl = TextEditingController();
    final kvahExpCtrl = TextEditingController();
    final kwDemCtrl = TextEditingController();
    final kvaDemCtrl = TextEditingController();
    final voltCtrl = TextEditingController();
    final ampCtrl = TextEditingController();
    final pfCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    final thdCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Text('New Reading',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Reading Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      dateController.text =
                          DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text('Energy Readings (kWh / kVArh)',
                    style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: kwhImpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kWh Import',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: kwhExpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kWh Export',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: kvahImpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kVArh Import',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: kvahExpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kVArh Export',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Demand & Power Quality',
                    style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: kwDemCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kW Demand',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: kvaDemCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kVA Demand',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: voltCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Voltage (V)',
                          hintText: '415',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: ampCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Current (A)',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: pfCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Power Factor',
                          hintText: '0.95',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: freqCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Frequency (Hz)',
                          hintText: '50',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: thdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'THD (%)',
                          hintText: '0.0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    final date = DateTime.tryParse(dateController.text);
                    if (date == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid date')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await context.read<EmsProvider>().addReading(
                          meterId: widget.meter.id,
                          readingDate: date,
                          kwhImport: double.tryParse(kwhImpCtrl.text),
                          kwhExport: double.tryParse(kwhExpCtrl.text),
                          kvahImport: double.tryParse(kvahImpCtrl.text),
                          kvahExport: double.tryParse(kvahExpCtrl.text),
                          kwDemand: double.tryParse(kwDemCtrl.text),
                          kvaDemand: double.tryParse(kvaDemCtrl.text),
                          voltageLNAvg: double.tryParse(voltCtrl.text),
                          currentAvg: double.tryParse(ampCtrl.text),
                          powerFactor: double.tryParse(pfCtrl.text),
                          frequency: double.tryParse(freqCtrl.text),
                          thd: double.tryParse(thdCtrl.text),
                        );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Reading'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
