import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/widgets/app_shell.dart';
import '../auth_bloc/auth_bloc.dart';
import '../auth_bloc/auth_event.dart';
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

  final List<Widget> _pages = const [
    DashboardPage(),
    ReadingEntryPage(),
    AnalysisPage(),
    ReportsPage(),
    MeterManagementPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 5) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Dashboard', 'Reading Entry', 'Analysis', 'Reports', 'Meter Management'];
    final hubTitle = _selectedIndex < titles.length ? titles[_selectedIndex] : 'PowerEMS';

    return AppShell(
      title: hubTitle,
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemTapped,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      userName: 'Admin',
      userEmail: 'admin@powerems.com',
      onLogout: () => context.read<AuthBloc>().add(const AppAuthLogoutRequested()),
      onThemeToggle: () => widget.onToggleTheme?.call(),
      isDark: widget.isDark,
      notificationCount: 3,
    );
  }
}
