import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/app_tour.dart';
import '../widgets/tour_keys.dart';

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

  @override
  void dispose() {
    TourLauncher.request.removeListener(_onTourRequested);
    _monthFilter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    _checkReadingReminder();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    TourLauncher.request.addListener(_onTourRequested);
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

  static const _tourPrefsKey = 'ems_tour_seen_v1';

  /// First-run guided tour — fires once per install/device.
  Future<void> _maybeStartTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_tourPrefsKey) ?? false;
      if (seen) return;
      await prefs.setBool(_tourPrefsKey, true);
      if (!mounted) return;
      _startTour();
    } catch (e) {
      // Tour is best-effort; never block startup on it.
    }
  }

  /// Replay requested from Settings → "Show App Tour". Pops any pushed
  /// routes (Settings / Billing) so the tour runs over the hub.
  void _onTourRequested() {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTour());
  }

  void _startTour() {
    showAppTour(
      context: context,
      steps: kAppTourSteps,
      switchTab: _switchTabForTour,
    );
  }

  void _switchTabForTour(int tab) {
    if (tab == 5) {
      setState(() {
        _selectedIndex = 5;
        _sidebarIndex = 7;
      });
      return;
    }
    setState(() {
      _selectedIndex = tab;
      _sidebarIndex = tab;
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
          const ReadingEntryPage(),
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
          key: kTourFabReadingKey,
          heroTag: 'fab-reading',
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Reading Entry'),
          onPressed: () => _onItemTapped(1),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          key: kTourFabMeterKey,
          heroTag: 'fab-add-meter',
          icon: const Icon(Icons.add),
          label: const Text('Add Your Meter'),
          onPressed: () => _onItemTapped(4),
        ),
      ],
    );
  }
}
