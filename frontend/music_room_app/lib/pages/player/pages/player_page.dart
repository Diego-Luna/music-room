import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/pages/events/widgets/swipeable_track_card.dart';
import 'package:music_room_app/pages/player/widgets/audio_visualizer.dart';
import 'package:music_room_app/pages/player/widgets/player_progress_bar.dart';
import 'package:music_room_app/providers/player_provider.dart';
import 'package:music_room_app/providers/events_provider.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/core/routing/safe_navigation.dart';
import 'package:music_room_app/models/track.dart';

// * Full-screen Player with swipe for voting.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
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
    final isMobile = AppBreakpoints.isCompact(context);
    final playerProvider = context.watch<PlayerProvider>();
    final isVoteRoom = playerProvider.voteRoomId != null;

    final track = playerProvider.currentTrack;
    if (track == null) {
      return const Scaffold(body: Center(child: Text('No track available')));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 680;
            final reservedHeight = isCompactHeight ? 280.0 : 330.0;
            final cardHeight = (constraints.maxHeight - reservedHeight).clamp(
              140.0,
              420.0,
            );

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PlayerHeader(isVoteRoom: isVoteRoom, theme: theme),
                AudioVisualizer(isPlaying: playerProvider.isPlaying),
                const SizedBox(height: AppDimens.xs),
                _PlayerTrackCard(
                  track: track,
                  cardHeight: cardHeight,
                  isMobile: isMobile,
                  isVoteRoom: isVoteRoom,
                  onVote: (action) =>
                      _vote(context, playerProvider, track, action),
                ),
                _PlayerBottomSection(
                  playerProvider: playerProvider,
                  track: track,
                  isCompactHeight: isCompactHeight,
                  onPlayPause: () =>
                      _handlePlayPause(context, playerProvider, track),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handlePlayPause(
    BuildContext context,
    PlayerProvider playerProvider,
    Track track,
  ) {
    if (playerProvider.isPlaying) {
      playerProvider.pause();
    } else {
      if (playerProvider.currentTrack == null) {
        playerProvider.playTrack(track);
      } else {
        playerProvider.resume();
      }
    }
    if (playerProvider.error != null) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(playerProvider.error!),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
      playerProvider.clearError();
    }
  }
}

class _PlayerHeader extends StatelessWidget {
  final bool isVoteRoom;
  final ThemeData theme;

  const _PlayerHeader({required this.isVoteRoom, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: [
          NeumorphicInteractiveContainer(
            onTap: () => context.safePop(fallbackRoute: routeHome),
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
          // Symmetrical spacer replacing the removed MIDI button
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final bool isCompact;

  const _PlaybackControls({
    required this.isPlaying,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playPadding = isCompact ? AppDimens.md : AppDimens.lg;
    final playIconSize = isCompact ? 38.0 : 48.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        NeumorphicInteractiveContainer(
          onTap: onPrevious,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            Icons.skip_previous_rounded,
            size: 36,
            color: hasPrevious
                ? theme.colorScheme.primary
                : theme.disabledColor,
          ),
        ),
        NeumorphicInteractiveContainer(
          onTap: onPlayPause,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
          padding: EdgeInsets.all(playPadding),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: playIconSize,
            color: theme.colorScheme.primary,
          ),
        ),
        NeumorphicInteractiveContainer(
          onTap: onNext,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            Icons.skip_next_rounded,
            size: 36,
            color: hasNext ? theme.colorScheme.primary : theme.disabledColor,
          ),
        ),
      ],
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
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xs,
      ),
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
            Expanded(child: _NowPlayingArtwork(track: track)),
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
                      color: theme.disabledColor,
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

class _NowPlayingArtwork extends StatelessWidget {
  final Track track;

  const _NowPlayingArtwork({required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artworkUrl = track.artworkUrl;

    Widget fallbackIcon() => Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: Icon(Icons.music_note, size: 80, color: theme.disabledColor),
    );

    if (artworkUrl != null && artworkUrl.isNotEmpty) {
      return Image.network(
        artworkUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallbackIcon(),
      );
    }

    return fallbackIcon();
  }
}

class _PlayerTrackCard extends StatelessWidget {
  final Track track;
  final double cardHeight;
  final bool isMobile;
  final bool isVoteRoom;
  final void Function(SwipeAction action) onVote;

  const _PlayerTrackCard({
    required this.track,
    required this.cardHeight,
    required this.isMobile,
    required this.isVoteRoom,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(milliseconds: 600),
      child: SizedBox(
        height: cardHeight,
        width: isMobile ? double.infinity : 400,
        child: isVoteRoom
            ? SwipeableTrackCard(
                key: ValueKey(track.id),
                trackTitle: track.title,
                artistName: track.artist,
                score: track.score,
                imageUrl: track.artworkUrl ?? 'placeholder',
                onSwiped: onVote,
              )
            : _NowPlayingCard(key: ValueKey(track.id), track: track),
      ),
    );
  }
}

class _PlayerBottomSection extends StatelessWidget {
  final PlayerProvider playerProvider;
  final Track track;
  final bool isCompactHeight;
  final VoidCallback onPlayPause;

  const _PlayerBottomSection({
    required this.playerProvider,
    required this.track,
    required this.isCompactHeight,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlayerProgressBar(),
          SizedBox(height: isCompactHeight ? AppDimens.md : AppDimens.xl),
          _PlaybackControls(
            isPlaying: playerProvider.isPlaying,
            hasPrevious: playerProvider.hasPrevious,
            hasNext: playerProvider.hasNext,
            onPrevious: playerProvider.playPrevious,
            onPlayPause: onPlayPause,
            onNext: playerProvider.playNext,
            isCompact: isCompactHeight,
          ),
          SizedBox(height: isCompactHeight ? AppDimens.sm : AppDimens.lg),
        ],
      ),
    );
  }
}
