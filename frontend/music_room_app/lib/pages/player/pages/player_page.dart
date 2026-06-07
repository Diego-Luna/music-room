import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/pages/events/widgets/swipeable_track_card.dart';
import 'package:music_room_app/pages/player/widgets/audio_visualizer.dart';
import 'package:music_room_app/widgets/interactive_3d/interactive_mpc.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/models/track.dart';
import 'package:music_room_app/config/mock/mock_data.dart';

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

// * Full-screen Player with swipe for voting.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  void _showMpcBeatpad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLarge),
          ),
          boxShadow: Theme.of(
            context,
          ).extension<AppDesignTokens>()?.neumorphicShadow,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppDimens.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            Text(
              'MPC BEATPAD',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: AppTypography.bold,
                letterSpacing: 2.0,
              ),
            ),
            const Expanded(child: InteractiveMpc()),
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                'Tap the pads to trigger live samples',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cast a real vote for the current track (vote rooms only), then advance.
  void _vote(
    BuildContext context,
    PlayerProvider player,
    Track track,
    SwipeAction action,
  ) {
    final roomId = player.voteRoomId;
    if (roomId == null) return;
    final value = action == SwipeAction.like
        ? 1
        : (action == SwipeAction.dislike ? -1 : 0);
    if (value == 0) return;

    final messenger = ScaffoldMessenger.of(context);
    context.read<EventsProvider>().voteForTrack(roomId, track.id, value);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          value > 0
              ? 'Voted UP for ${track.title}'
              : 'Voted DOWN for ${track.title}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    player.playNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    final isMobile = MediaQuery.of(context).size.width < 700;
    final playerProvider = context.watch<PlayerProvider>();
    final isVoteRoom = playerProvider.voteRoomId != null;

    // * Fallback: get first available track from any room
    final fallbackTrack = MockData.rooms.expand((r) => r.tracks).firstOrNull;
    final track = playerProvider.currentTrack ?? fallbackTrack;
    if (track == null) {
      return const Scaffold(body: Center(child: Text('No track available')));
    }

    // Real playback progress from the audio backend (30s Deezer preview).
    final position = playerProvider.position;
    final duration = playerProvider.duration;
    final totalMs = duration.inMilliseconds;
    final progress = totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final remaining = duration > position ? duration - position : Duration.zero;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Solid Background for Neumorphism
          Container(color: theme.scaffoldBackgroundColor),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // Header (Minimize Button)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  child: Row(
                    children: [
                      NeumorphicInteractiveContainer(
                        onTap: () => context.pop(),
                        padding: const EdgeInsets.all(AppDimens.sm),
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isVoteRoom ? 'Live Voting Room' : 'Now Playing',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: AppTypography.bold,
                            letterSpacing: 1.2,
                            color: theme.disabledColor,
                          ),
                        ),
                      ),
                      NeumorphicInteractiveContainer(
                        onTap: _showMpcBeatpad,
                        padding: const EdgeInsets.all(AppDimens.sm),
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Visualizer
                AudioVisualizer(isPlaying: playerProvider.isPlaying),
                const SizedBox(height: AppDimens.md),

                // 3. Track card. In a vote room it's the swipe-to-vote card
                //    (casts a real vote, then advances); elsewhere it's a
                //    static now-playing card (no misleading vote affordance).
                FadeIn(
                  duration: const Duration(milliseconds: 600),
                  child: SizedBox(
                    height: isMobile
                        ? MediaQuery.of(context).size.height * 0.45
                        : 500,
                    width: isMobile ? double.infinity : 400,
                    child: isVoteRoom
                        ? SwipeableTrackCard(
                            key: ValueKey(track.id),
                            trackTitle: track.title,
                            artistName: track.artist,
                            score: track.score,
                            imageUrl: track.artworkUrl ?? "placeholder",
                            onSwiped: (action) =>
                                _vote(context, playerProvider, track, action),
                          )
                        : _NowPlayingCard(
                            key: ValueKey(track.id),
                            track: track,
                          ),
                  ),
                ),

                const Spacer(),

                // 4. Neumorphic Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                  child: Column(
                    children: [
                      // Progress Bar
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                          boxShadow: tokens?.neumorphicPressedShadow,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusPill,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.xs,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                            Text(
                              '-${_formatDuration(remaining)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.xl),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NeumorphicInteractiveContainer(
                            onTap: playerProvider.playPrevious,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppDimens.xs,
                            ),
                            padding: const EdgeInsets.all(AppDimens.md),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.skip_previous_rounded,
                              size: 36,
                              color: playerProvider.hasPrevious
                                  ? theme.colorScheme.primary
                                  : theme.disabledColor,
                            ),
                          ),
                          NeumorphicInteractiveContainer(
                            onTap: () {
                              if (playerProvider.isPlaying) {
                                playerProvider.pause();
                              } else {
                                if (playerProvider.currentTrack == null) {
                                  playerProvider.playTrack(track);
                                } else {
                                  playerProvider.resume();
                                }
                              }
                              // Show alert if no permission
                              if (playerProvider.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(playerProvider.error!),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                playerProvider.clearError();
                              }
                            },
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppDimens.xs,
                            ),
                            padding: const EdgeInsets.all(AppDimens.lg),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          NeumorphicInteractiveContainer(
                            onTap: playerProvider.playNext,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppDimens.xs,
                            ),
                            padding: const EdgeInsets.all(AppDimens.md),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.skip_next_rounded,
                              size: 36,
                              color: playerProvider.hasNext
                                  ? theme.colorScheme.primary
                                  : theme.disabledColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimens.xxl * 1.5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// * Static "now playing" card used outside vote rooms (playlists, home), where
// * a swipe-to-vote affordance would be misleading.
class _NowPlayingCard extends StatelessWidget {
  final Track track;

  const _NowPlayingCard({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      margin: const EdgeInsets.all(AppDimens.lg),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
            tokens?.cardRadius ?? BorderRadius.circular(AppDimens.radiusLarge),
        boxShadow: tokens?.neumorphicShadow,
      ),
      child: ClipRRect(
        borderRadius:
            tokens?.cardRadius ?? BorderRadius.circular(AppDimens.radiusLarge),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppDimens.lg),
              width: double.infinity,
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    track.artist,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
