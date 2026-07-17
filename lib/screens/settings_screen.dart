import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ems_provider.dart';
import '../services/sync_service.dart';
import '../core/utils/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Configuration',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _configRow(
                    'OpenAI',
                    AppConfig.openAiApiKey.isNotEmpty
                        ? 'Configured (${AppConfig.openAiApiKey.substring(0, 8)}...)'
                        : 'Not configured',
                    Icons.auto_awesome,
                  ),
                  const SizedBox(height: 8),
                  _configRow(
                    'Supabase',
                    AppConfig.supabaseUrl.isNotEmpty
                        ? 'Connected'
                        : 'Not configured',
                    Icons.cloud,
                  ),
                  const SizedBox(height: 8),
                  _configRow(
                    'Model',
                    AppConfig.openAiModel,
                    Icons.model_training,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data Management',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sync Now'),
                    subtitle: Consumer<EmsProvider>(
                      builder: (_, provider, _) {
                        final status = provider.syncService.status;
                        return Text(
                          status == SyncStatus.syncing
                              ? 'Syncing...'
                              : status == SyncStatus.error
                                  ? 'Last sync failed'
                                  : status == SyncStatus.success
                                      ? 'Sync complete'
                                      : 'Tap to sync data to cloud',
                        );
                      },
                    ),
                    onTap: () => context.read<EmsProvider>().syncNow(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Export Readings'),
                    subtitle: const Text('CSV format'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export via report service')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: const Text('Delete Old Analysis'),
                    subtitle: const Text('Remove analysis older than 90 days'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cleaned up')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _configRow('App', AppConfig.appName, Icons.info),
                  const SizedBox(height: 4),
                  _configRow('Version', AppConfig.appVersion, Icons.tag),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _configRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
