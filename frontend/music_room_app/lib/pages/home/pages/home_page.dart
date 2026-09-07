import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/pages/home/widgets/quick_picks_carousel.dart';
import 'package:music_room_app/pages/home/widgets/songs_carousel.dart';
import 'package:music_room_app/pages/home/widgets/recent_events_list.dart';
import 'package:music_room_app/pages/home/widgets/home_search_results.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';

/// Apple Music / Youtube Music style home page with track search
class HomePage extends StatefulWidget {
  final RoomRepository? repository;

  const HomePage({super.key, this.repository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  RoomRepository get _repo => widget.repository ?? roomRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistsProvider>().fetchPlaylists();
      context.read<EventsProvider>().fetchEvents();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searchQuery = trimmed;
      _isSearching = true;
      _searchError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _repo.searchTracks(query);
      if (!mounted || _searchQuery != query) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || _searchQuery != query) return;
      setState(() {
        _searchError = 'Search failed. Make sure you are online.';
        _isSearching = false;
      });
    }
  }

  void _handleTrackTap(Track track, int index) {
    context.read<PlayerProvider>().playTrack(
      track,
      queue: _searchResults,
      index: index,
    );
    context.push(routePlayer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Opacity(opacity: 0.6, child: BackgroundFloaters()),
          CustomScrollView(
            clipBehavior: Clip.hardEdge,
            slivers: [
              _buildAppBar(context),
              _buildSearchBar(),
              SliverToBoxAdapter(
                child: _searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildDefaultContent(context),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimens.xxl * 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      toolbarHeight: 76.0,
      floating: true,
      pinned: false,
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
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.xs,
        ),
        child: NeumorphicSearchBar(
          controller: _searchController,
          hintText: 'Search songs, artists...',
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return HomeSearchResults(
      query: _searchQuery,
      tracks: _searchResults,
      isLoading: _isSearching,
      errorMessage: _searchError,
      onTrackTap: _handleTrackTap,
    );
  }

  Widget _buildDefaultContent(BuildContext context) {
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final eventsProvider = context.watch<EventsProvider>();

    final mixes = playlistsProvider.playlists;
    final recentEvents = eventsProvider.events;
    final allTracks = {
      ...playlistsProvider.playlists.expand((r) => r.tracks),
      ...eventsProvider.events.expand((r) => r.tracks),
    }.toList();

    return FadeIn(
      duration: const Duration(milliseconds: 600),
      child: SlideIn(
        beginOffset: const Offset(0, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.lg),
            if (allTracks.isNotEmpty) _buildTopSongs(context, allTracks),
            if (mixes.isNotEmpty) _buildPlaylists(context, mixes),
            if (recentEvents.isNotEmpty)
              _buildRecentEvents(context, recentEvents),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSongs(BuildContext context, List<Track> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Text(
            'Top Songs',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: AppTypography.bold),
          ),
        ),
        const SizedBox(height: AppDimens.md),
        SongsCarousel(songs: songs),
        const SizedBox(height: AppDimens.xxl),
      ],
    );
  }

  Widget _buildPlaylists(BuildContext context, dynamic mixes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Text(
            'Your Playlists',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: AppTypography.bold),
          ),
        ),
        const SizedBox(height: AppDimens.md),
        QuickPicksCarousel(mixes: mixes),
        const SizedBox(height: AppDimens.xxl),
      ],
    );
  }

  Widget _buildRecentEvents(BuildContext context, dynamic recentEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Recently Played Events',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final nav = context.read<NavigationProvider>();
                  final i = nav.destinations.indexWhere(
                    (d) => d.route == routeEvents,
                  );
                  nav.navigateToIndex(context, i);
                },
                child: Text(
                  'See All',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: RecentEventsList(events: recentEvents),
        ),
      ],
    );
  }
}
