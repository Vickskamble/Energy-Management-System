import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

class SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleCollapse;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;
  final bool isDark;
  final int notificationCount;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onToggleCollapse,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.onThemeToggle,
    required this.isDark,
    this.notificationCount = 0,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  @override
  Widget build(BuildContext context) {
    final items = [
      SidebarItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        index: 0,
      ),
      SidebarItem(
        icon: Icons.edit_note_outlined,
        activeIcon: Icons.edit_note_rounded,
        label: 'Reading Entry',
        index: 1,
      ),
      SidebarItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        label: 'Analysis',
        index: 2,
      ),
      SidebarItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description_rounded,
        label: 'Reports',
        index: 3,
      ),
      SidebarItem(
        icon: Icons.speed_outlined,
        activeIcon: Icons.speed_rounded,
        label: 'Meters',
        index: 4,
      ),
      SidebarItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: 'Readings',
        index: 8,
      ),
      SidebarItem(
        icon: Icons.file_upload_outlined,
        activeIcon: Icons.file_upload_rounded,
        label: 'Excel Import',
        index: 7,
      ),
      SidebarItem(
        icon: Icons.workspace_premium_outlined,
        activeIcon: Icons.workspace_premium_rounded,
        label: 'Plan & Billing',
        index: 6,
      ),
      SidebarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
        index: 5,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: widget.isCollapsed
          ? AppSpacing.sidebarCollapsedWidth
          : AppSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        border: Border(
          right: BorderSide(
            color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: widget.isDark ? null : AppShadows.sidebar,
      ),
      child: Column(
        children: [
          Container(
            height: AppSpacing.topBarHeight,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: widget.isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'PowerEMS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCollapsed ? AppSpacing.sm : AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = widget.selectedIndex == item.index;
                return Tooltip(
                  message: item.label,
                  waitDuration: const Duration(milliseconds: 600),
                  child: _SidebarItem(
                    item: item,
                    selected: selected,
                    isCollapsed: widget.isCollapsed,
                    isDark: widget.isDark,
                    onTap: () => widget.onItemSelected(item.index),
                  ),
                );
              },
            ),
          ),
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    return Container(
      padding: EdgeInsets.all(
        widget.isCollapsed ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          if (widget.isCollapsed) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: Icon(
                widget.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 18,
              ),
              onPressed: widget.onThemeToggle,
              color: widget.isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textSecondary,
              tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
            ),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 18),
              onPressed: widget.onLogout,
              color: AppColors.danger,
              tooltip: 'Logout',
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.userName.isNotEmpty
                        ? widget.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.userEmail,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark
                              ? AppColors.textDarkSecondary
                              : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 18,
                  ),
                  onPressed: widget.onThemeToggle,
                  color: widget.isDark
                      ? AppColors.textDarkSecondary
                      : AppColors.textSecondary,
                  tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Logout', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final SidebarItem item;
  final bool selected;
  final bool isCollapsed;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.isCollapsed,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark
                        ? AppColors.sidebarItemActiveDark
                        : AppColors.sidebarItemActive)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 22,
                  color: selected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textSecondary),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.textDarkSecondary
                                  : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
                if (selected && !isCollapsed)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
