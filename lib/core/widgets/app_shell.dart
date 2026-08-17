import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';

class AppShell extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;
  final bool isDark;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;

  const AppShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.body,
    this.floatingActionButton,
    this.actions,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.onThemeToggle,
    required this.isDark,
    this.notificationCount = 0,
    this.onNotificationsTap,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return _buildMobileLayout();
    return _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(widget.title),
        actions: [_buildUserChip(context, compact: true), ...?widget.actions],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.userEmail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 5; i++)
              ListTile(
                selected: widget.selectedIndex == i,
                leading: Icon(_mobileIcon(i)),
                title: Text(_mobileLabel(i)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onItemSelected(i);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Plan & Billing'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onItemSelected(6);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onItemSelected(5);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Compact user chip shown in the top bar (desktop: avatar + name/email,
  /// mobile: avatar only to save space).
  Widget _buildUserChip(BuildContext context, {bool compact = false}) {
    final initial = widget.userName.isNotEmpty
        ? widget.userName.trim()[0].toUpperCase()
        : 'U';
    final avatar = CircleAvatar(
      radius: compact ? 14 : 16,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
    if (compact) {
      return Padding(padding: const EdgeInsets.only(right: 4), child: avatar);
    }
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.userName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                widget.userEmail,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _mobileIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard_rounded;
      case 1:
        return Icons.edit_note_rounded;
      case 2:
        return Icons.insights_rounded;
      case 3:
        return Icons.description_rounded;
      case 4:
        return Icons.speed_rounded;
      case 5:
        return Icons.settings_rounded;
      default:
        return Icons.circle;
    }
  }

  String _mobileLabel(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Reading Entry';
      case 2:
        return 'Analysis';
      case 3:
        return 'Reports';
      case 4:
        return 'Meter Management';
      case 5:
        return 'Settings';
      default:
        return '';
    }
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSidebar(
            selectedIndex: widget.selectedIndex,
            isCollapsed: _sidebarCollapsed,
            onItemSelected: widget.onItemSelected,
            onToggleCollapse: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            userName: widget.userName,
            userEmail: widget.userEmail,
            onLogout: widget.onLogout,
            onThemeToggle: widget.onThemeToggle,
            isDark: widget.isDark,
            notificationCount: widget.notificationCount,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  onMenuTap: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  onNotificationsTap: widget.onNotificationsTap,
                  notificationCount: widget.notificationCount,
                  actions: [
                    _buildUserChip(context),
                    ...?widget.actions,
                  ],
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
