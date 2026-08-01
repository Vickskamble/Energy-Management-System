import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/widgets/app_shell.dart';
import '../auth_bloc/auth_bloc.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import 'dashboard_page.dart';
import 'reading_entry_page.dart';
import 'analysis_page.dart';
import 'reports_page.dart';
import 'meter_management_page.dart';
import '../pages/settings_page.dart';

class MainNavigationHub extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const MainNavigationHub({super.key, this.onToggleTheme, this.isDark = false});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<EnergyBloc>().add(const LoadInitialDashboardData());
  }

  void _onItemTapped(int index) {
    if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Dashboard',
      'Reading Entry',
      'Analysis',
      'Reports',
      'Meter Management',
    ];
    final hubTitle = _selectedIndex < titles.length
        ? titles[_selectedIndex]
        : 'PowerEMS';
    final authState = context.watch<AuthBloc>().state;
    final email = authState is AppAuthAuthenticated
        ? authState.email
        : 'user@powerems.com';
    final name = authState is AppAuthAuthenticated
        ? authState.email.split('@').first
        : 'User';

    return AppShell(
      title: hubTitle,
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemTapped,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Dashboard auto-refreshes only while its tab is visible.
          DashboardPage(isActive: _selectedIndex == 0),
          const ReadingEntryPage(),
          const AnalysisPage(),
          const ReportsPage(),
          const MeterManagementPage(),
        ],
      ),
      userName: name,
      userEmail: email,
      onLogout: () =>
          context.read<AuthBloc>().add(const AppAuthLogoutRequested()),
      onThemeToggle: () => widget.onToggleTheme?.call(),
      isDark: widget.isDark,
      notificationCount: 0,
    );
  }
}
