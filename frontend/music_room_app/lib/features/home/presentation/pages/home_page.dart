import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/core/animations/animated_scale_button.dart';
import 'package:music_room_app/features/home/presentation/widgets/quick_picks_carousel.dart';
import 'package:music_room_app/features/home/presentation/widgets/recent_events_list.dart';
import 'package:music_room_app/providers/theme_provider.dart';

/// Apple Music / Youtube Music style home page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated data
    final mixes = [
      'Chill Mix',
      'Discover Mix',
      'New Releases',
      'Your Top Songs',
    ];
    final recentEvents = [
      'Friday Night Party',
      'Office Vibes',
      'Study Session',
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.lg,
                bottom: AppDimens.md,
              ),
              title: Text(
                'Listen Now',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: AppTypography.extraBold,
                ),
              ),
            ),
            actions: [
              AnimatedScaleButton(
                onPressed: () {
                  context.read<ThemeProvider>().toggleTheme();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: AppDimens.md),
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: Theme.of(
                      context,
                    ).extension<AppDesignTokens>()?.neumorphicShadow,
                  ),
                  child: Icon(
                    context.watch<ThemeProvider>().themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
              AnimatedScaleButton(
                onPressed: () {},
                child: Container(
                  margin: const EdgeInsets.only(right: AppDimens.lg),
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: Theme.of(
                      context,
                    ).extension<AppDesignTokens>()?.neumorphicShadow,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: FadeIn(
              duration: const Duration(milliseconds: 600),
              child: SlideIn(
                beginOffset: const Offset(0, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimens.lg),

                    // Quick Picks Section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                      ),
                      child: Text(
                        'Quick Picks',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.md),
                    QuickPicksCarousel(mixes: mixes),

                    const SizedBox(height: AppDimens.xxl),

                    // Recent Events Section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Recently Played Events',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: AppTypography.bold),
                          ),
                          Text(
                            'See All',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontWeight: AppTypography.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                      ),
                      child: RecentEventsList(events: recentEvents),
                    ),

                    const SizedBox(
                      height: AppDimens.xxl * 3,
                    ), // Extra space for navbar,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
