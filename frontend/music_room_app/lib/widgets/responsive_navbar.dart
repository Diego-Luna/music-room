import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

// ! Responsive navigation bar that reads destinations from `NavigationProvider`.
//* - On small widths it renders a custom Neumorphic bottom bar.
//* - On wide screens it renders a top horizontal navigation bar.
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
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      padding: const EdgeInsets.only(
        top: AppDimens.sm,
        bottom: AppDimens.xl,
      ), // Extra bottom padding for safe area
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: tokens?.neumorphicShadow,
      ),
      clipBehavior: Clip.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(nav.destinations.length, (index) {
          final item = nav.destinations[index];
          final isActive = index == nav.currentIndex;

          return Expanded(
            child: NeumorphicInteractiveContainer(
              onTap: () => nav.navigateToIndex(context, index),
              isForcedPressed: isActive,
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimens.xs,
                vertical: AppDimens.sm,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                    size: AppDimens.iconMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
                      fontWeight: isActive
                          ? AppTypography.bold
                          : AppTypography.normal,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWebNav(BuildContext context, NavigationProvider nav) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: tokens?.neumorphicShadow,
      ),
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
                fontWeight: AppTypography.extraBold,
              ),
            ),
            const Spacer(),
            ...List.generate(nav.destinations.length, (index) {
              final item = nav.destinations[index];
              final isActive = index == nav.currentIndex;

              return Padding(
                padding: const EdgeInsets.only(left: AppDimens.md),
                child: NeumorphicInteractiveContainer(
                  onTap: () => nav.navigateToIndex(context, index),
                  isForcedPressed: isActive,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                        size: AppDimens.iconMedium,
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                          fontWeight: isActive
                              ? AppTypography.bold
                              : AppTypography.normal,
                        ),
                      ),
                    ],
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
