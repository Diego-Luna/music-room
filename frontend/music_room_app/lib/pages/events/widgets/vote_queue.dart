import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/widgets/placeholder_card.dart';

// * Shared queue for a vote room. The track already playing is a player.
// * Waiting tracks take a vote, or clear it, from a button on the row.
class VoteQueue extends StatelessWidget {
  final List<Track> tracks;
  final String? currentTrackId;
  final bool isPaused;
  final bool canControl;
  final void Function(Track track) onToggle;
  final void Function(Track track) onTogglePlayback;

  const VoteQueue({
    super.key,
    required this.tracks,
    required this.currentTrackId,
    required this.isPaused,
    required this.canControl,
    required this.onToggle,
    required this.onTogglePlayback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Track? nowPlaying;
    for (final track in tracks) {
      if (track.id == currentTrackId) {
        nowPlaying = track;
        break;
      }
    }
    final queue = [
      for (final track in tracks)
        if (track.id != currentTrackId) track,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nowPlaying != null) ...[
          _header(theme, 'Now playing'),
          _nowPlayingTile(context, nowPlaying),
        ],
        _header(theme, 'Up next'),
        if (queue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.xl,
              vertical: AppDimens.md,
            ),
            child: Text(
              tracks.isEmpty
                  ? 'No tracks yet. Suggest one with +.'
                  : 'Nothing else is waiting.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final track in queue) _queueTile(context, track),
      ],
    );
  }

  Widget _header(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.lg,
        AppDimens.xl,
        AppDimens.md,
      ),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }

  Widget _nowPlayingTile(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final canHear = _hasPreview(track);
    final votesLabel = _votesLabel(track.score);
    return Padding(
      key: ValueKey('now_${track.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: track.title,
        subtitle: canHear
            ? '${track.artist} • $votesLabel'
            : '${track.artist} • No preview for this track',
        onTap: canControl && canHear ? () => onTogglePlayback(track) : null,
        trailing: Icon(
          _playbackIcon(),
          color: canHear ? theme.colorScheme.primary : theme.disabledColor,
        ),
      ),
    );
  }

  Widget _queueTile(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final voted = track.myVote == 1;
    return Padding(
      key: ValueKey('vote_${track.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm / 2,
      ),
      child: PlaceholderCard(
        title: track.title,
        subtitle: '${track.artist} • ${_votesLabel(track.score)}',
        onTap: () => onToggle(track),
        trailing: Text(
          voted ? 'Voted' : 'Vote',
          style: theme.textTheme.labelLarge?.copyWith(
            color: voted ? theme.colorScheme.primary : theme.disabledColor,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }

  IconData _playbackIcon() {
    if (!canControl) {
      return isPaused ? Icons.pause_rounded : Icons.graphic_eq;
    }
    return isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded;
  }

  bool _hasPreview(Track track) {
    final preview = track.previewUrl;
    return preview != null && preview.isNotEmpty;
  }

  String _votesLabel(int score) => score == 1 ? '1 vote' : '$score votes';
}
