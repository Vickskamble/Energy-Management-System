import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../auth_bloc/auth_bloc.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;

  const SettingsScreen({super.key, this.isDark = false, this.onToggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
            Tab(text: 'Account', icon: Icon(Icons.person_outline, size: 18)),
            Tab(
              text: 'Appearance',
              icon: Icon(Icons.palette_outlined, size: 18),
            ),
            Tab(text: 'System', icon: Icon(Icons.memory_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildAccount(), _buildAppearance(), _buildSystem()],
      ),
    );
  }

  Widget _buildAccount() {
    final authState = context.watch<AuthBloc>().state;
    final email = authState is AppAuthAuthenticated
        ? authState.email
        : 'user@powerems.com';
    final name = authState is AppAuthAuthenticated
        ? authState.email.split('@').first
        : 'User';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Account',
          subtitle: 'Your account information',
        ),
        AppCard(
          child: Column(
            children: [
              _accountRow(Icons.person_outline, 'Full Name', name),
              const Divider(),
              _accountRow(Icons.email_outlined, 'Email', email),
              const Divider(),
              _accountRow(
                Icons.business_outlined,
                'Organization',
                'PowerEMS Inc.',
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Sign out',
                  style: TextStyle(fontSize: 14, color: AppColors.danger),
                ),
                trailing: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            context.read<AuthBloc>().add(
                              const AppAuthLogoutRequested(),
                            );
                          },
                          child: const Text(
                            'Sign out',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearance() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'Appearance',
          subtitle: 'Customize the look and feel',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  widget.isDark ? 'Dark theme active' : 'Light theme active',
                  style: const TextStyle(fontSize: 12),
                ),
                value: widget.isDark,
                onChanged: (_) => widget.onToggleTheme?.call(),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystem() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppSectionHeader(
          title: 'System',
          subtitle: 'System information and configuration',
        ),
        AppCard(
          child: Column(
            children: [
              _accountRow(Icons.info_outline, 'App Version', '1.0.0'),
              const Divider(),
              _accountRow(Icons.cloud_outlined, 'Supabase', 'Connected'),
              const Divider(),
              _accountRow(
                Icons.auto_awesome_outlined,
                'Analysis Engine',
                'Rule-based',
              ),
            ],
          ),
        ),
      ],
    );
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
