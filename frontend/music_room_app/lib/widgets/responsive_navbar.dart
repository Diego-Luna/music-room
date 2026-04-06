import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/theme/app_theme.dart';
import 'package:music_room_app/providers/navigation_provider.dart';

// ! Responsive navigation bar that reads destinations from `NavigationProvider`.
// * - On small widths it renders a `BottomNavigationBar`.
// * - On wide screens it renders a top horizontal navigation bar.
class ResponsiveNavbar extends StatelessWidget {
  // ! Temporal:  Optional override to force mobile layout for testing.
  final bool? forceMobile;

  const ResponsiveNavbar({super.key, this.forceMobile});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final width = MediaQuery.of(context).size.width;
    final isMobile = forceMobile ?? width < 700;

    if (isMobile) {
      return _buildMobileNav(context, nav);
    }
    return _buildWebNav(context, nav);
  }

  Widget _buildMobileNav(BuildContext context, NavigationProvider nav) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: nav.currentIndex,
      onTap: (i) => nav.navigateToIndex(context, i),
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.colorScheme.primary,
      selectedItemColor: theme.colorScheme.secondary,
      unselectedItemColor: theme.disabledColor,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      items: nav.destinations
          .map(
            (d) => BottomNavigationBarItem(
              icon: Icon(d.icon),
              label: d.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildWebNav(BuildContext context, NavigationProvider nav) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.xxl,
        vertical: AppDimens.lg,
      ),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Row(
          children: [
            Text(
              'Music Room',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: AppTypography.extraBold,
              ),
            ),
            const Spacer(),
            ...List.generate(nav.destinations.length, (index) {
              final item = nav.destinations[index];
              final isActive = index == nav.currentIndex;
              return Padding(
                padding: const EdgeInsets.only(left: AppDimens.xl),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => nav.navigateToIndex(context, index),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isActive ? theme.colorScheme.secondary : theme.disabledColor,
                          size: AppDimens.iconMedium,
                        ),
                        const SizedBox(width: AppDimens.xs),
                        Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isActive ? theme.colorScheme.secondary : theme.disabledColor,
                            fontWeight: isActive ? AppTypography.semibold : AppTypography.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
