import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/playlists_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/pages/playlists/widgets/create_playlist_dialog.dart';
import 'package:music_room_app/pages/events/widgets/create_event_dialog.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';
import 'package:music_room_app/models/room.dart';

enum SocialTab { playlists, events }

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  SocialTab _activeTab = SocialTab.playlists;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreatePlaylistDialog(),
    );
  }

  void _showCreateEventDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateEventDialog(),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isPlaylists) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPlaylists ? Icons.queue_music : Icons.how_to_vote,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              isPlaylists ? 'No playlists yet' : 'No events yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              isPlaylists
                  ? 'Create a collaborative playlist and add tracks from Deezer.'
                  : 'Start a live voting session and let everyone pick the next track.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.lg),
            PrimaryButton(
              onPressed: () => isPlaylists
                  ? _showCreatePlaylistDialog(context)
                  : _showCreateEventDialog(context),
              leading: const Icon(Icons.add),
              label: isPlaylists ? 'Create Playlist' : 'Create Event',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.md),
            Text('No results found', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.sm),
            Text(
              'No items match "$_searchQuery".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // * Extracted: Animated sliding indicator for the toggle
  Widget _buildToggleIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return AnimatedAlign(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: _activeTab == SocialTab.playlists
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            boxShadow: tokens?.neumorphicShadow,
          ),
        ),
      ),
    );
  }

  // * Extracted: Single tab button for the toggle
  Widget _buildTabButton({
    required BuildContext context,
    required Key key,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isActive ? AppTypography.bold : AppTypography.normal,
              color: isActive ? theme.colorScheme.primary : theme.disabledColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingToggle(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        boxShadow: tokens?.neumorphicPressedShadow,
      ),
      child: Stack(
        children: [
          _buildToggleIndicator(context),
          Row(
            children: [
              _buildTabButton(
                context: context,
                key: const Key('playlists_tab_button'),
                label: 'Playlists',
                isActive: _activeTab == SocialTab.playlists,
                onTap: () {
                  if (_activeTab != SocialTab.playlists) {
                    setState(() {
                      _activeTab = SocialTab.playlists;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
              ),
              _buildTabButton(
                context: context,
                key: const Key('events_tab_button'),
                label: 'Events',
                isActive: _activeTab == SocialTab.events,
                onTap: () {
                  if (_activeTab != SocialTab.events) {
                    setState(() {
                      _activeTab = SocialTab.events;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // * Extracted: Filter playlists by search query
  List<Room> _filterPlaylists(List<Room> playlists) {
    return playlists.where((playlist) {
      final nameMatch = playlist.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final descMatch =
          playlist.description?.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ??
          false;
      return nameMatch || descMatch;
    }).toList();
  }

  // * Extracted: Filter events by search query
  List<Room> _filterEvents(List<Room> events) {
    return events.where((event) {
      final nameMatch = event.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final descMatch =
          event.description?.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ??
          false;
      return nameMatch || descMatch;
    }).toList();
  }

  // * Extracted: Single playlist list item
  Widget _buildPlaylistItem(BuildContext context, Room playlist, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: StaggeredList(
        index: index,
        child: PlaceholderCard(
          title: playlist.name,
          subtitle: 'Collaborative Playlist • ${playlist.tracks.length} songs',
          leading: Hero(
            tag: 'playlist_cover_${playlist.id}',
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                boxShadow: Theme.of(
                  context,
                ).extension<AppDesignTokens>()?.neumorphicPressedShadow,
              ),
              child: Icon(
                Icons.playlist_play,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          onTap: () => context.go(
            '$routeSocial/$routePlaylistDetail',
            extra: {'playlist': playlist},
          ),
        ),
      ),
    );
  }

  // * Extracted: Single event list item
  Widget _buildEventItem(
    BuildContext context,
    Room event,
    int index,
    EventsProvider eventsProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: StaggeredList(
        index: index,
        child: PlaceholderCard(
          title: event.name,
          subtitle: 'Vote Session • ${event.tracks.length} tracks',
          leading: Hero(
            tag: 'event_cover_${event.id}',
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                boxShadow: Theme.of(
                  context,
                ).extension<AppDesignTokens>()?.neumorphicPressedShadow,
              ),
              child: Icon(
                Icons.how_to_vote,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          onTap: () {
            eventsProvider.selectEvent(event);
            context.go(
              '$routeSocial/$routeEventDetail',
              extra: {'event': event},
            );
          },
        ),
      ),
    );
  }

  // * Extracted: List content (empty, search empty, or items)
  Widget _buildListContent({
    required BuildContext context,
    required bool isEmpty,
    required bool isSearchEmpty,
    required bool isPlaylists,
    required List<Room> filteredPlaylists,
    required List<Room> filteredEvents,
    required EventsProvider eventsProvider,
  }) {
    final itemsCount = isPlaylists
        ? filteredPlaylists.length
        : filteredEvents.length;

    if (isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(context, isPlaylists),
      );
    }
    if (isSearchEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildSearchEmptyState(context),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= itemsCount) return null;
        if (isPlaylists) {
          return _buildPlaylistItem(context, filteredPlaylists[index], index);
        }
        return _buildEventItem(
          context,
          filteredEvents[index],
          index,
          eventsProvider,
        );
      }, childCount: itemsCount),
    );
  }

  // * Extracted: SliverAppBar for the social page
  Widget _buildSliverAppBar(BuildContext context, bool isPlaylists) {
    return SliverAppBar(
      title: const Text('Social'),
      centerTitle: true,
      floating: true,
      pinned: false,
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor.withValues(alpha: 0.8),
      actions: [
        Center(
          child: NeumorphicIconButton(
            key: const Key('social_create_button'),
            icon: isPlaylists ? Icons.playlist_add : Icons.add_box_outlined,
            tooltip: isPlaylists ? 'New Playlist' : 'New Event',
            onTap: () => isPlaylists
                ? _showCreatePlaylistDialog(context)
                : _showCreateEventDialog(context),
          ),
        ),
      ],
    );
  }

  // * Extracted: SliverToBoxAdapter for the sliding toggle
  Widget _buildSlidingToggleAdapter(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.sm,
        ),
        child: _buildSlidingToggle(context),
      ),
    );
  }

  // * Extracted: SliverToBoxAdapter for the search bar
  Widget _buildSearchBarAdapter(BuildContext context, bool isPlaylists) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: NeumorphicSearchBar(
          key: const Key('social_search_bar'),
          controller: _searchController,
          hintText: isPlaylists ? 'Search playlists...' : 'Search events...',
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
      ),
    );
  }

  // * Extracted: CustomScrollView with all slivers
  Widget _buildScrollView({
    required BuildContext context,
    required bool isPlaylists,
    required bool isEmpty,
    required bool isSearchEmpty,
    required List<Room> filteredPlaylists,
    required List<Room> filteredEvents,
    required EventsProvider eventsProvider,
  }) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, isPlaylists),
        _buildSlidingToggleAdapter(context),
        _buildSearchBarAdapter(context, isPlaylists),
        _buildListContent(
          context: context,
          isEmpty: isEmpty,
          isSearchEmpty: isSearchEmpty,
          isPlaylists: isPlaylists,
          filteredPlaylists: filteredPlaylists,
          filteredEvents: filteredEvents,
          eventsProvider: eventsProvider,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl * 3)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsProvider = context.watch<PlaylistsProvider>();
    final eventsProvider = context.watch<EventsProvider>();

    final isPlaylists = _activeTab == SocialTab.playlists;
    final isLoading = isPlaylists
        ? playlistsProvider.isLoading
        : eventsProvider.isLoading;

    final filteredPlaylists = _filterPlaylists(playlistsProvider.playlists);
    final filteredEvents = _filterEvents(eventsProvider.events);

    final isEmpty = isPlaylists
        ? playlistsProvider.playlists.isEmpty
        : eventsProvider.events.isEmpty;
    final isSearchEmpty =
        _searchQuery.isNotEmpty &&
        (isPlaylists ? filteredPlaylists.isEmpty : filteredEvents.isEmpty);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildScrollView(
              context: context,
              isPlaylists: isPlaylists,
              isEmpty: isEmpty,
              isSearchEmpty: isSearchEmpty,
              filteredPlaylists: filteredPlaylists,
              filteredEvents: filteredEvents,
              eventsProvider: eventsProvider,
            ),
        ],
      ),
    );
  }
}
