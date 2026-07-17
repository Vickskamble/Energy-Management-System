import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ems_provider.dart';
import '../services/sync_service.dart';
import 'site_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmsProvider>().loadSites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMS'),
        actions: [
          Consumer<EmsProvider>(
            builder: (_, provider, _) {
              if (provider.syncService.status == SyncStatus.syncing) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: Icon(
                  provider.syncService.status == SyncStatus.error
                      ? Icons.sync_problem
                      : Icons.sync,
                ),
                onPressed: () => provider.syncNow(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<EmsProvider>(),
                  child: const SettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body:           Consumer<EmsProvider>(
        builder: (_, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.sites.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadSites();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.sites.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _buildSummaryCards(provider);
                }
                final site = provider.sites[i - 1];
                return _buildSiteCard(context, site);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSiteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.electrical_services, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Sites Added Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first site to start tracking energy',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddSiteDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Site'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(EmsProvider provider) {
    int totalMeters = 0;
    int totalReadings = 0;
    int criticalIssues = 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard(
                context,
                icon: Icons.business,
                label: 'Sites',
                value: '${provider.sites.length}',
                color: Colors.blue,
              ),
              _summaryCard(
                context,
                icon: Icons.speed,
                label: 'Meters',
                value: '$totalMeters',
                color: Colors.green,
              ),
              _summaryCard(
                context,
                icon: Icons.analytics,
                label: 'Readings',
                value: '$totalReadings',
                color: Colors.orange,
              ),
              _summaryCard(
                context,
                icon: Icons.warning,
                label: 'Issues',
                value: '$criticalIssues',
                color: criticalIssues > 0 ? Colors.red : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard(BuildContext context, dynamic site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey[100],
          child: const Icon(Icons.business, color: Colors.blueGrey),
        ),
        title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: site.location != null ? Text(site.location!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<EmsProvider>(),
                child: SiteDetailScreen(site: site),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSiteDialog(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final demandController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Site'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
                hintText: 'e.g., Main Factory',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g., Mumbai, India',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: demandController,
              decoration: const InputDecoration(
                labelText: 'Contract Demand (kVA, optional)',
                hintText: 'e.g., 500',
              ),
              keyboardType: TextInputType.number,
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
              final provider = context.read<EmsProvider>();
              await provider.createSite(
                nameController.text.trim(),
                location: locationController.text.trim().isEmpty
                    ? null
                    : locationController.text.trim(),
                contractDemandKva: double.tryParse(demandController.text),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}


