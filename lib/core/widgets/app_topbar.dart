import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showSearch;
  final bool showNotifications;
  final bool showSettings;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationsTap;
  final int notificationCount;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showSearch = false,
    this.showNotifications = true,
    this.showSettings = false,
    this.onMenuTap,
    this.onNotificationsTap,
    this.notificationCount = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.topBarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: AppSpacing.topBarHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          ?leading,
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenuTap,
              tooltip: 'Menu',
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          ...?actions,
          if (showSearch)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {},
              tooltip: 'Search',
            ),
          if (showNotifications &&
              (notificationCount > 0 || onNotificationsTap != null))
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: onNotificationsTap,
                  tooltip: 'Notifications',
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          notificationCount > 9 ? '9+' : '$notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {},
              tooltip: 'Settings',
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

class AppBreadcrumb extends StatelessWidget {
  final List<String> items;

  const AppBreadcrumb({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(items.length * 2 - 1, (i) {
        if (i.isOdd) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: AppColors.textSecondary,
            ),
          );
        }
        final idx = i ~/ 2;
        final isLast = idx == items.length - 1;
        return Text(
          items[idx],
          style: TextStyle(
            fontSize: 12,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
            color: isLast ? AppColors.primary : AppColors.textSecondary,
          ),
        );
      }),
    );
  }
}
