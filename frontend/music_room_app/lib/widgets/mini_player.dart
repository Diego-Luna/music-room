import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/providers/player_provider.dart';

/// Spotify-style bar shown while a track is loaded and the full player is closed.
///
/// Sits above the bottom navigation. Hidden when nothing has been played, and
/// absent from the full-screen player because that route lives outside the shell.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerProvider player;
    try {
      player = context.watch<PlayerProvider>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final progress = (player.position.inMilliseconds / 30000).clamp(0.0, 1.0);

    return _MiniPlayerBar(
      track: track,
      isPlaying: player.isPlaying,
      progress: progress,
      onPrevious: player.skipBackward,
      onNext: player.playNext,
      onPlayPause: () {
        if (player.isPlaying) {
          player.pause();
        } else {
          player.resume();
        }
      },
      onOpen: () => context.push(routePlayer),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onOpen,
  });

  final Track track;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = AppBreakpoints.isCompact(context)
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;

    return Material(
      key: const Key('mini_player'),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.disabledColor.withValues(alpha: 0.25),
              color: theme.colorScheme.primary,
            ),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('mini_player_open'),
                      onTap: onOpen,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                        ),
                        child: Row(
                          children: [
                            _Artwork(url: track.artworkUrl),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: AppTypography.bold,
                                    ),
                                  ),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.disabledColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Control(
                    key: const Key('mini_player_previous'),
                    tooltip: 'Previous',
                    icon: Icons.keyboard_arrow_left_rounded,
                    onPressed: onPrevious,
                  ),
                  _Control(
                    key: const Key('mini_player_play'),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: onPlayPause,
                  ),
                  _Control(
                    key: const Key('mini_player_next'),
                    tooltip: 'Next',
                    icon: Icons.keyboard_arrow_right_rounded,
                    onPressed: onNext,
                  ),
                  const SizedBox(width: AppDimens.xs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      child: SizedBox(
        width: 40,
        height: 40,
        child: url != null && url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(theme),
              )
            : _fallback(theme),
      ),
    );
  }

  Widget _fallback(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.music_note, color: theme.colorScheme.primary, size: 22),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: theme.colorScheme.primary,
      disabledColor: theme.disabledColor,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    );
  }
}
