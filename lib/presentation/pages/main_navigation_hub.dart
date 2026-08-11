import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/reading_reminder.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/month_filter_bar.dart';
import '../../data/repositories/energy_repository.dart';
import '../auth_bloc/auth_bloc.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import 'dashboard_page.dart';
import 'reading_entry_page.dart';
import 'analysis_page.dart';
import 'reports_page.dart';
import 'meter_management_page.dart';
import 'billing_page.dart';
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

  /// Shared month selection — one filter for Dashboard, Analysis & Reports.
  final MonthFilterController _monthFilter = MonthFilterController();

  @override
  void dispose() {
    _monthFilter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    _checkReadingReminder();
  }

  /// Month-end reading reminder (Issue 7F) — fire once per month.
  Future<void> _checkReadingReminder() async {
    try {
      final now = DateTime.now();
      final logs = await context.read<EnergyRepository>().getAllLogs();
      final thisMonth = logs
          .where(
            (e) => e.loggedAt.year == now.year && e.loggedAt.month == now.month,
          )
          .length;
      await ReadingReminderService.maybeRemind(
        readingCountThisMonth: thisMonth,
      );
    } catch (e) {
      // Reminder is best-effort; never block startup on it.
    }
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
    if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillingPage()),
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
          DashboardPage(
            isActive: _selectedIndex == 0,
            monthFilter: _monthFilter,
          ),
          const ReadingEntryPage(),
          AnalysisPage(monthFilter: _monthFilter),
          ReportsPage(monthFilter: _monthFilter),
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
