import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/services/proximity_service.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/staggered_list.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/neumorphic_icon_button.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/pages/events/widgets/create_event_dialog.dart';
import 'package:music_room_app/pages/events/widgets/proximity_approach_sheet.dart';
import 'package:music_room_app/widgets/neumorphic_search_bar.dart';

//* Events list page — symmetric to PlaylistsPage. Tapping an event opens its
//* live voting interface (EventDetailPage).
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String _searchQuery = '';

  /// VI.2 — avoid re-showing the same approach sheet in one session.
  final Set<String> _announcedProximityIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<EventsProvider>().fetchEvents();
      if (!mounted) return;
      await _scanProximity();
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

  /// VI.2 — if current position is inside a public geo event, show its info.
  Future<void> _scanProximity({bool force = false}) async {
    final position = LocationConfig.current;
    if (position == null) return;

    final events = context.read<EventsProvider>().events;
    final nearby = ProximityService.findNearbyPublicEvents(
      position: position,
      events: events,
    );
    if (nearby.isEmpty) return;

    for (final hit in nearby) {
      if (!force && _announcedProximityIds.contains(hit.room.id)) continue;
      _announcedProximityIds.add(hit.room.id);
      if (!mounted) return;

      await ProximityApproachSheet.show(
        context,
        nearby: hit,
        onOpen: () => _openEvent(hit.room),
      );
      // * One sheet at a time for the demo.
      break;
    }
  }

  /// Desktop / school demo: teleport into the first public geo event's venue.
  Future<void> _enterProximityZoneDemo() async {
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>().events;
    final geoPublic = events
        .where((e) => e.isPublic && e.isGeoGated)
        .toList();

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
    await LocationConfig.setOverride(
      lat: target.voteLocationLat!,
      lng: target.voteLocationLng!,
    );
    if (!mounted) return;

    _announcedProximityIds.remove(target.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Entered zone for "${target.name}"'),
        backgroundColor: Colors.green,
      ),
    );
    await _scanProximity(force: true);
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
                  toolbarHeight: 90.0,
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  actions: [
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.sensors,
                        tooltip: 'Enter proximity zone (demo)',
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
                                ? 'Vote Session • geo • ${event.tracks.length} tracks'
                                : 'Vote Session • ${event.tracks.length} tracks',
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
