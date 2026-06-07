import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/widgets/track_search_sheet.dart';

/// Event "suggest a track" bottom-sheet. Thin wrapper around the shared
/// [TrackSearchSheet] — only wires the suggest action and copy.
class SuggestTrackDialog extends StatelessWidget {
  final Room room;

  const SuggestTrackDialog({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.read<EventsProvider>();
    return TrackSearchSheet(
      title: 'Suggest Song',
      onSelected: (track) => eventsProvider.suggestTrack(room.id, track),
      confirmationBuilder: (track) => 'Suggested "${track.title}"!',
    );
  }
}
