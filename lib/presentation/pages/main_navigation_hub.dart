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
import 'excel_import_page.dart';
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

  /// Highlighted sidebar item — can be 5 (Settings) / 6 (Billing) while those
  /// routes are pushed on top of the IndexedStack body.
  int _sidebarIndex = 0;

  /// Shared month selection — one filter for Dashboard, Analysis & Reports.
  final MonthFilterController _monthFilter = MonthFilterController();

  /// Lets the hub ask Reading Entry whether it holds unsaved values before
  /// switching tabs (discard guard).
  final GlobalKey<ReadingEntryPageState> _readingEntryKey =
      GlobalKey<ReadingEntryPageState>();

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
    if (index != _selectedIndex &&
        _selectedIndex == 1 &&
        (_readingEntryKey.currentState?.isDirty ?? false)) {
      _confirmDiscardReadingForm(() => _goTo(index));
      return;
    }
    _goTo(index);
  }

  Future<void> _confirmDiscardReadingForm(VoidCallback proceed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved reading?'),
        content: const Text(
          'You have unsubmitted values in Reading Entry. '
          'Switching tabs will discard them.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard & leave'),
          ),
        ],
      ),
    );
    if (ok == true) proceed();
  }

  void _goTo(int index) {
    if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      ).then((_) => setState(
        () =>
            _sidebarIndex = _selectedIndex == 5 ? 7 : _selectedIndex,
      ));
      setState(() => _sidebarIndex = index);
      return;
    }
    if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillingPage()),
      ).then((_) => setState(
        () =>
            _sidebarIndex = _selectedIndex == 5 ? 7 : _selectedIndex,
      ));
      setState(() => _sidebarIndex = index);
      return;
    }
    // Sidebar "Import" (7) sits at stack position 5 — Settings/Billing are
    // pushed routes, so the IndexedStack slot is free.
    if (index == 7) {
      setState(() {
        _selectedIndex = 5;
        _sidebarIndex = 7;
      });
      return;
    }
    setState(() {
      _selectedIndex = index;
      _sidebarIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Dashboard',
      'Reading Entry',
      'Analysis',
      'Reports',
      'Meter Management',
      'Excel Import',
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
      selectedIndex: _sidebarIndex,
      onItemSelected: _onItemTapped,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Dashboard auto-refreshes only while its tab is visible.
          DashboardPage(
            isActive: _selectedIndex == 0,
            monthFilter: _monthFilter,
            onNavigateToMeters: () => _onItemTapped(4),
          ),
          ReadingEntryPage(key: _readingEntryKey),
          AnalysisPage(monthFilter: _monthFilter),
          ReportsPage(monthFilter: _monthFilter),
          const MeterManagementPage(),
          const ExcelImportPage(),
        ],
      ),
      userName: name,
      userEmail: email,
      onLogout: () =>
          context.read<AuthBloc>().add(const AppAuthLogoutRequested()),
      onThemeToggle: () => widget.onToggleTheme?.call(),
      isDark: widget.isDark,
      notificationCount: 0,
      floatingActionButton:
          _selectedIndex == 0 ? _dashboardFab() : null,
    );
  }

  /// Dashboard-only FABs — quick actions for the two most common tasks.
  Widget _dashboardFab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab-reading',
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Reading Entry'),
          onPressed: () => _onItemTapped(1),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'fab-add-meter',
          icon: const Icon(Icons.add),
          label: const Text('Add Your Meter'),
          onPressed: () => _onItemTapped(4),
        ),
      ],
    );
  }
}
