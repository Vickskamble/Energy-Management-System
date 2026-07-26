import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
            Tab(text: 'General', icon: Icon(Icons.tune_rounded, size: 18)),
            Tab(text: 'Account', icon: Icon(Icons.person_outline, size: 18)),
            Tab(text: 'Notifications', icon: Icon(Icons.notifications_outlined, size: 18)),
            Tab(text: 'Security', icon: Icon(Icons.lock_outline, size: 18)),
            Tab(text: 'Appearance', icon: Icon(Icons.palette_outlined, size: 18)),
            Tab(text: 'System', icon: Icon(Icons.memory_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildGeneral(),
          _buildAccount(),
          _buildNotifications(),
          _buildSecurity(),
          _buildAppearance(),
          _buildSystem(),
        ],
      ),
    );
  }

  Widget _buildGeneral() {
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'General Settings', subtitle: 'Configure your application preferences'),
      AppCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Auto-sync data', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Automatically sync readings to cloud', style: TextStyle(fontSize: 12)),
            value: true,
            onChanged: (_) {},
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Offline mode', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Work offline and sync when connected', style: TextStyle(fontSize: 12)),
            value: false,
            onChanged: (_) {},
            contentPadding: EdgeInsets.zero,
          ),
        ],
      )),
      const SizedBox(height: AppSpacing.lg),
      AppCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('English (US)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      )),
    ]);
  }

  Widget _buildAccount() {
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'Account', subtitle: 'Manage your account settings'),
      AppCard(child: Column(
        children: [
          _accountRow(Icons.person_outline, 'Full Name', 'Admin User'),
          const Divider(),
          _accountRow(Icons.email_outlined, 'Email', 'admin@powerems.com'),
          const Divider(),
          _accountRow(Icons.business_outlined, 'Organization', 'PowerEMS Inc.'),
        ],
      )),
    ]);
  }

  Widget _buildNotifications() {
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'Notifications', subtitle: 'Configure how you receive alerts'),
      AppCard(child: Column(
        children: [
          SwitchListTile(title: const Text('Push notifications'), value: true, onChanged: (_) {}, contentPadding: EdgeInsets.zero),
          const Divider(),
          SwitchListTile(title: const Text('Email alerts'), value: true, onChanged: (_) {}, contentPadding: EdgeInsets.zero),
          const Divider(),
          SwitchListTile(title: const Text('PF penalty warnings'), value: true, onChanged: (_) {}, contentPadding: EdgeInsets.zero),
          const Divider(),
          SwitchListTile(title: const Text('MD breach warnings'), value: true, onChanged: (_) {}, contentPadding: EdgeInsets.zero),
        ],
      )),
    ]);
  }

  Widget _buildSecurity() {
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'Security', subtitle: 'Manage your security preferences'),
      AppCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(title: const Text('Two-factor authentication'), value: false, onChanged: (_) {}, contentPadding: EdgeInsets.zero),
          const Divider(),
          ListTile(title: const Text('Change password', style: TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right), contentPadding: EdgeInsets.zero, onTap: () {}),
          const Divider(),
          ListTile(title: const Text('Active sessions', style: TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right), contentPadding: EdgeInsets.zero, onTap: () {}),
        ],
      )),
    ]);
  }

  Widget _buildAppearance() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'Appearance', subtitle: 'Customize the look and feel'),
      AppCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('Theme', style: TextStyle(fontSize: 14)),
            subtitle: Text(isDark ? 'Dark Mode' : 'Light Mode', style: const TextStyle(fontSize: 12)),
            trailing: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      )),
    ]);
  }

  Widget _buildSystem() {
    return ListView(padding: const EdgeInsets.all(AppSpacing.page), children: [
      AppSectionHeader(title: 'System', subtitle: 'System information and configuration'),
      AppCard(child: Column(
        children: [
          _accountRow(Icons.info_outline, 'App Version', '1.0.0'),
          const Divider(),
          _accountRow(Icons.cloud_outlined, 'Supabase', 'Connected'),
          const Divider(),
          _accountRow(Icons.auto_awesome_outlined, 'Analysis Engine', 'Rule-based'),
        ],
      )),
    ]);
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
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
