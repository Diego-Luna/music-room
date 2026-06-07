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
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/pages/events/widgets/create_event_dialog.dart';

//* Events list page — symmetric to PlaylistsPage. Tapping an event opens its
//* live voting interface (EventDetailPage).
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
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

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final isEmpty = eventsProvider.events.isEmpty;

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
                  pinned: false,
                  backgroundColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  actions: [
                    Center(
                      child: NeumorphicIconButton(
                        icon: Icons.add_box_outlined,
                        tooltip: 'New Event',
                        onTap: () => _showCreateEventDialog(context),
                      ),
                    ),
                  ],
                ),
                if (isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= eventsProvider.events.length) return null;
                    final event = eventsProvider.events[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                        vertical: AppDimens.sm / 2,
                      ),
                      child: StaggeredList(
                        index: index,
                        child: PlaceholderCard(
                          title: event.name,
                          subtitle:
                              'Vote Session • ${event.tracks.length} tracks',
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
                                Icons.how_to_vote,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          onTap: () {
                            eventsProvider.selectEvent(event);
                            context.go(
                              '$routeEvents/$routeEventDetail',
                              extra: {'event': event},
                            );
                          },
                        ),
                      ),
                    );
                  }, childCount: eventsProvider.events.length),
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
}
