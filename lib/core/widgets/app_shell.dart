import 'package:flutter/material.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) return _buildMobileLayout();
    return _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
        title: Text(widget.title),
        actions: widget.actions,
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
    );
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
            onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            userName: widget.userName,
            userEmail: widget.userEmail,
            onLogout: widget.onLogout,
            onThemeToggle: widget.onThemeToggle,
            isDark: widget.isDark,
            notificationCount: widget.notificationCount,
          ),
          VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  onMenuTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  onNotificationsTap: widget.onNotificationsTap,
                  notificationCount: widget.notificationCount,
                  actions: widget.actions,
                ),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
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
