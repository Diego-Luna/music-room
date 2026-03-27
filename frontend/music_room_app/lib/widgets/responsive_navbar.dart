import 'package:flutter/material.dart';
import 'package:music_room_app/theme/app_theme.dart';

class NavItem {
  final String label;
  final IconData icon;
  final int index;

  NavItem({
    required this.label,
    required this.icon,
    required this.index,
  });
}

class ResponsiveNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavItem> items;
  final bool isMobile;

  const ResponsiveNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _buildBottomNav(context);
    }
    return _buildTopNav(context);
  }
  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.colorScheme.primary,
      selectedItemColor: theme.colorScheme.secondary,
      unselectedItemColor: theme.disabledColor,
      items: items
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildTopNav(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.xxl,
        vertical: AppDimens.lg,
      ),
      child: Row(
        children: [
          Text(
            'Music Room',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const Spacer(),
          ...items.map((item) => _buildNavItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, NavItem item) {
    final theme = Theme.of(context);
    final isActive = item.index == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(left: AppDimens.xl),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onTap(item.index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                color: isActive ? theme.colorScheme.secondary : theme.disabledColor,
                size: AppDimens.iconMedium,
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isActive ? theme.colorScheme.secondary : theme.disabledColor,
                  fontWeight: isActive ? AppTypography.semibold : AppTypography.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
