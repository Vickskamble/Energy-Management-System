import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ems_provider.dart';
import '../models/site.dart';
import '../models/analysis_result.dart';
import 'panel_detail_screen.dart';
import 'analysis_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmsProvider>();
      provider.selectSite(widget.site);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        actions: [
          Consumer<EmsProvider>(
            builder: (_, provider, _) {
              if (provider.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'analyze') {
                    await provider.runFullAnalysis(widget.site.id);
                  } else if (v == 'export') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export coming soon')),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'analyze',
                    child: ListTile(
                      leading: Icon(Icons.auto_awesome),
                      title: Text('Run Full Analysis'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Export Data'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<EmsProvider>(
        builder: (_, provider, _) {
          if (provider.loading && provider.panels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.selectSite(widget.site);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSiteInfoCard(context, provider),
                const SizedBox(height: 16),
                if (provider.siteDashboard != null)
                  _buildDashboardSummary(context, provider.siteDashboard!),
                const SizedBox(height: 16),
                _buildAnalysisSummary(context, provider),
                const SizedBox(height: 16),
                Text(
                  'Panels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (provider.panels.isEmpty)
                  _buildEmptyPanels(context)
                else
                  ...provider.panels.map(
                    (panel) => _buildPanelCard(context, panel),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPanelDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Panel'),
      ),
    );
  }

  Widget _buildSiteInfoCard(BuildContext context, EmsProvider provider) {
    final site = widget.site;
    final contract = provider.siteDashboard?['contract_demand_kva'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    site.location ?? 'No location set',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            if (contract != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.electrical_services, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Contract Demand: ${contract.toStringAsFixed(0)} kVA',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSummary(BuildContext context, Map<String, dynamic> dash) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Summary',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _dashStat('Panels', '${dash['total_panels'] ?? 0}', Icons.dashboard),
                _dashStat('Meters', '${dash['total_meters'] ?? 0}', Icons.speed),
                _dashStat('Readings', '${dash['total_readings'] ?? 0}', Icons.analytics),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _dashStat('Total (kWh)', '${(dash['total_kwh'] as double?)?.toStringAsFixed(0) ?? 0}', Icons.bolt),
                _dashStat('Max Demand', '${(dash['max_demand_kw'] as double?)?.toStringAsFixed(1) ?? 0} kW', Icons.trending_up),
                _dashStat('Avg PF', '${(dash['avg_power_factor'] as double?)?.toStringAsFixed(2) ?? 0}', Icons.power),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary(BuildContext context, EmsProvider provider) {
    final issues = provider.analysisResults;
    final critical = issues.where((a) =>
        a.severity == Severity.critical || a.severity == Severity.high).toList();

    if (issues.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                'No issues found. Run analysis to check system health.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                Text('AI Insights',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const AnalysisScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (critical.isNotEmpty)
              ...critical.take(3).map((a) => _issueTile(context, a)),
          ],
        ),
      ),
    );
  }

  Widget _issueTile(BuildContext context, dynamic analysis) {
    Color severityColor;
    final sev = analysis.severity as Severity;
    switch (sev) {
      case Severity.critical:
        severityColor = Colors.red;
      case Severity.high:
        severityColor = Colors.orange;
      case Severity.medium:
        severityColor = Colors.amber;
      case Severity.low:
        severityColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(analysis.title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(analysis.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPanels(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.dashboard_customize, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text('No panels added yet',
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelCard(BuildContext context, dynamic panel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.dashboard),
        title: Text(panel.name),
        subtitle: panel.panelType != null ? Text(panel.panelType!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<EmsProvider>(),
                child: PanelDetailScreen(panel: panel),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPanelDialog(BuildContext context) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Panel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Panel Name',
                hintText: 'e.g., Main LT Panel',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: 'Panel Type (optional)',
                hintText: 'e.g., LT, HT, Sub-DB',
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
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await context.read<EmsProvider>().createPanel(
                    widget.site.id,
                    nameController.text.trim(),
                    panelType: typeController.text.trim().isEmpty
                        ? null
                        : typeController.text.trim(),
                  );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
