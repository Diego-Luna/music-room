import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/features/events/presentation/widgets/swipeable_track_card.dart';
import 'package:music_room_app/features/player/presentation/widgets/audio_visualizer.dart';
import 'package:music_room_app/widgets/interactive_3d/interactive_mpc.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/config/mock/mock_data.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    final isMobile = MediaQuery.of(context).size.width < 700;
    final playerProvider = context.watch<PlayerProvider>();

    // If no track is playing, load a default one
    final track = playerProvider.currentTrack ?? MockData.tracks.first;

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
                          'Live Voting Room',
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

                // 3. Swipeable Card for Voting (The Core mechanic)
                FadeIn(
                  duration: const Duration(milliseconds: 600),
                  child: SizedBox(
                    height: isMobile
                        ? MediaQuery.of(context).size.height * 0.45
                        : 500,
                    width: isMobile ? double.infinity : 400,
                    child: SwipeableTrackCard(
                      key: ValueKey(track.id),
                      trackTitle: track.title,
                      artistName: track.artist,
                      imageUrl: track.albumArtUrl ?? "placeholder",
                      onSwiped: (action) {
                        if (action == SwipeAction.like) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Voted: LIKE'),
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          );
                        } else if (action == SwipeAction.dislike) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Voted: DISLIKE'),
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          );
                        }
                      },
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
                          widthFactor: playerProvider.isPlaying ? 0.45 : 0.3,
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
                              playerProvider.isPlaying ? '1:45' : '1:12',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                            Text(
                              playerProvider.isPlaying ? '-2:15' : '-3:45',
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
                            onTap: () {},
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
                              color: theme.colorScheme.primary,
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
                            onTap: () {},
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
                              color: theme.colorScheme.primary,
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
