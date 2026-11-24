import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/services/proximity_watcher.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/pages/events/widgets/create_event_dialog.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';
import 'package:music_room_app/widgets/shelf_chip.dart';

enum _EventShelf { yours, joined, discover }

//* Events list page. One list, split into the caller's own rooms, rooms they
//* joined, and public rooms they have not joined. Tapping an event opens its
//* live voting interface (EventDetailPage).
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String _searchQuery = '';
  _EventShelf _shelf = _EventShelf.yours;

  bool _onShelf(Room event) {
    switch (_shelf) {
      case _EventShelf.yours:
        return event.myRole == 'OWNER';
      case _EventShelf.joined:
        return event.myRole == 'MEMBER' || event.myRole == 'ADMIN';
      case _EventShelf.discover:
        return event.myRole == null;
    }
  }

  String _relationLabel(Room event) {
    switch (event.myRole) {
      case 'OWNER':
        return 'Yours';
      case 'ADMIN':
      case 'MEMBER':
        return 'Member';
      default:
        return 'Public';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsProvider>().fetchEvents();
    });
  }

  void _showCreateEventDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateEventDialog(),
    );
  }

  void _openEvent(Room event) {
    final eventsProvider = context.read<EventsProvider>();
    eventsProvider.selectEvent(event);
    context.go('$routeEvents/$routeEventDetail', extra: {'event': event});
  }

  /// Desktop / school demo: teleport into the first public geo event's venue.
  /// [ProximityWatcher] then opens the approach sheet automatically.
  Future<void> _enterProximityZoneDemo() async {
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>().events;
    final geoPublic = events.where((e) => e.isPublic && e.isGeoGated).toList();

    if (geoPublic.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No public geo event yet. Create one with a location licence first.',
          ),
        ),
      );
      return;
    }

    final target = geoPublic.first;
    final alreadyThere =
        LocationConfig.current?.lat == target.voteLocationLat &&
        LocationConfig.current?.lng == target.voteLocationLng;
    await LocationConfig.setOverride(
      lat: target.voteLocationLat!,
      lng: target.voteLocationLng!,
    );
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('Entered zone for "${target.name}"'),
        backgroundColor: Colors.green,
      ),
    );
    if (alreadyThere) {
      ProximityWatcher.instance?.replay(target.id);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppDimens.md),
            Text('No events yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Start a live voting session and let everyone pick the next track.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.lg),
            PrimaryButton(
              onPressed: () => _showCreateEventDialog(context),
              leading: const Icon(Icons.add),
              label: 'Create Event',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelves(BuildContext context) {
    const shelves = <(_EventShelf, String, Key)>[
      (_EventShelf.yours, 'Yours', Key('events_tab_yours')),
      (_EventShelf.joined, 'Joined', Key('events_tab_joined')),
      (_EventShelf.discover, 'Discover', Key('events_tab_discover')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < shelves.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.sm),
            Expanded(
              child: ShelfChip(
                key: shelves[i].$3,
                label: shelves[i].$2,
                selected: _shelf == shelves[i].$1,
                onTap: () => setState(() => _shelf = shelves[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShelfEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (_shelf) {
      _EventShelf.yours => 'You have not created an event yet.',
      _EventShelf.joined => 'You have not joined an event yet.',
      _EventShelf.discover => 'No public events to discover.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
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
              'No events match "$_searchQuery".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final isEmpty = eventsProvider.events.isEmpty;
    final filteredEvents = eventsProvider.events.where((event) {
      if (!_onShelf(event)) return false;
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
    final isSearchEmpty = _searchQuery.isNotEmpty && filteredEvents.isEmpty;
    final isShelfEmpty =
        _searchQuery.isEmpty && filteredEvents.isEmpty && !isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Opacity(opacity: 0.4, child: BackgroundFloaters()),

          if (eventsProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: const Text('Events'),
                  centerTitle: true,
                  floating: true,
                  toolbarHeight: 76.0,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  actions: [
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.sensors,
                        tooltip: 'Simulate walking into a nearby event',
                        onTap: _enterProximityZoneDemo,
                      ),
                    ),
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.add_box_outlined,
                        tooltip: 'New Event',
                        onTap: () => _showCreateEventDialog(context),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _buildShelves(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.lg),
                    child: NeumorphicSearchBar(
                      key: const Key('events_search_bar'),
                      hintText: 'Search events...',
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                if (isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else if (isSearchEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildSearchEmptyState(context),
                  )
                else if (isShelfEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildShelfEmptyState(context),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= filteredEvents.length) return null;
                      final event = filteredEvents[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                          vertical: AppDimens.sm / 2,
                        ),
                        child: StaggeredList(
                          index: index,
                          child: PlaceholderCard(
                            title: event.name,
                            subtitle: event.isGeoGated
                                ? '${_relationLabel(event)} • geo • ${event.tracks.length} tracks'
                                : '${_relationLabel(event)} • ${event.tracks.length} tracks',
                            leading: Hero(
                              tag: 'event_cover_${event.id}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusMedium,
                                  ),
                                  boxShadow: Theme.of(context)
                                      .extension<AppDesignTokens>()
                                      ?.neumorphicPressedShadow,
                                ),
                                child: Icon(
                                  event.isGeoGated
                                      ? Icons.location_on
                                      : Icons.how_to_vote,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            onTap: () => _openEvent(event),
                          ),
                        ),
                      );
                    }, childCount: filteredEvents.length),
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
}
