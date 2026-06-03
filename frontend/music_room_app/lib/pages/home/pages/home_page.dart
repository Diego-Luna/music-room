import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/pages/home/widgets/quick_picks_carousel.dart';
import 'package:music_room_app/pages/home/widgets/songs_carousel.dart';
import 'package:music_room_app/pages/home/widgets/recent_events_list.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/track.dart';

/// Apple Music / Youtube Music style home page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistsProvider>().fetchPlaylists();
      context.read<EventsProvider>().fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final eventsProvider = context.watch<EventsProvider>();

    final mixes = playlistsProvider.playlists;
    final recentEvents = eventsProvider.events;

    final allTracks = [
      ...playlistsProvider.playlists.expand((r) => r.tracks),
      ...eventsProvider.events.expand((r) => r.tracks),
    ].toSet().toList();

    final topSongs = allTracks;

    return Scaffold(
      body: Stack(
        children: [
          // Background floaters for a living background
          const Opacity(opacity: 0.6, child: BackgroundFloaters()),

          CustomScrollView(
            clipBehavior: Clip.none,
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: true,
                pinned:
                    false, // I set pinned to false so the title doesn't stay on top when scrolling down
                backgroundColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.8),
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
                  NeumorphicInteractiveContainer(
                    onTap: () {
                      context.read<ThemeProvider>().toggleTheme();
                    },
                    margin: const EdgeInsets.all(AppDimens.md),
                    padding: const EdgeInsets.all(AppDimens.sm),
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Icon(
                      context.watch<ThemeProvider>().themeMode == ThemeMode.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  NeumorphicInteractiveContainer(
                    onTap: () {},
                    margin: const EdgeInsets.all(AppDimens.md),
                    padding: const EdgeInsets.all(AppDimens.sm),
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
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

                        if (topSongs.isNotEmpty) ...[
                          // Songs Section
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.lg,
                            ),
                            child: Text(
                              'Top Songs',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: AppTypography.bold),
                            ),
                          ),
                          const SizedBox(height: AppDimens.md),
                          SongsCarousel(songs: topSongs),
                          const SizedBox(height: AppDimens.xxl),
                        ],

                        if (mixes.isNotEmpty) ...[
                          // Playlists Section
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.lg,
                            ),
                            child: Text(
                              'Your Playlists',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: AppTypography.bold),
                            ),
                          ),
                          const SizedBox(height: AppDimens.md),
                          QuickPicksCarousel(mixes: mixes),
                          const SizedBox(height: AppDimens.xxl),
                        ],

                        if (recentEvents.isNotEmpty) ...[
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
                                      ?.copyWith(
                                        fontWeight: AppTypography.bold,
                                      ),
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
                        ],

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
        ],
      ),
    );
  }
}
