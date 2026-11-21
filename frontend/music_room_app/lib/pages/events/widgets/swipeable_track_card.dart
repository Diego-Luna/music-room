import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/providers/events_provider.dart';

enum SwipeAction { like, dislike, none }

// ! A Tinder-style swipeable card for track voting.
class SwipeableTrackCard extends StatefulWidget {
  final String trackTitle;
  final String artistName;
  final int score;
  final String imageUrl;
  final Function(SwipeAction) onSwiped;

  const SwipeableTrackCard({
    super.key,
    required this.trackTitle,
    required this.artistName,
    required this.score,
    required this.imageUrl,
    required this.onSwiped,
  });

  @override
  State<SwipeableTrackCard> createState() => SwipeableTrackCardState();
}

class SwipeableTrackCardState extends State<SwipeableTrackCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  Offset _animStartOffset = Offset.zero;
  Offset _animTargetOffset = Offset.zero;
  double _animStartAngle = 0.0;
  bool _animIsEscaping = false;
  SwipeAction _pendingAction = SwipeAction.none;
  Curve _animCurve = Curves.easeOut;

  // Size of the screen determines limits
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 500),
          )
          ..addListener(() {
            final t = _animCurve.transform(_animationController.value);
            setState(() {
              _dragOffset = Offset.lerp(
                _animStartOffset,
                _animTargetOffset,
                t,
              )!;
              _dragAngle =
                  ui.lerpDouble(
                    _animStartAngle,
                    _animIsEscaping ? _animStartAngle : 0.0,
                    t,
                  ) ??
                  0.0;
            });
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              final completedAction = _pendingAction;
              _pendingAction = SwipeAction.none;
              if (completedAction != SwipeAction.none) {
                widget.onSwiped(completedAction);
                if (mounted) {
                  setState(() {
                    _dragOffset = Offset.zero;
                    _dragAngle = 0.0;
                  });
                }
              }
            }
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      // Rotates depending on x offset.
      _dragAngle = _dragOffset.dx / _screenSize.width * 0.4;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final offsetX = _dragOffset.dx;

    // Thresholds to consider it a swipe
    if (velocityX > 1000 || offsetX > _screenSize.width * 0.3) {
      _animateTo(Offset(_screenSize.width, 0), SwipeAction.like);
    } else if (velocityX < -1000 || offsetX < -_screenSize.width * 0.3) {
      _animateTo(Offset(-_screenSize.width, 0), SwipeAction.dislike);
    } else {
      // Snap back to center
      _animateTo(Offset.zero, SwipeAction.none);
    }
  }

  void _animateTo(Offset targetOffset, SwipeAction action) {
    _animStartOffset = _dragOffset;
    _animTargetOffset = targetOffset;
    _animStartAngle = _dragAngle;
    _animIsEscaping = targetOffset != Offset.zero;
    _pendingAction = action;
    _animCurve = _animIsEscaping ? Curves.easeOut : Curves.elasticOut;
    _animationController.forward(from: 0);
  }

  // API to trigger swiping programmatically via buttons
  void triggerLike() {
    _animateTo(Offset(_screenSize.width, 0), SwipeAction.like);
  }

  void triggerDislike() {
    _animateTo(Offset(-_screenSize.width, 0), SwipeAction.dislike);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();
    final radius =
        tokens?.cardRadius ?? BorderRadius.circular(AppDimens.radiusLarge);

    // Calculate background colors based on drag
    final likeOpacity = math
        .max(0.0, (_dragOffset.dx / (_screenSize.width * 0.3)))
        .clamp(0.0, 1.0);
    final dislikeOpacity = math
        .max(0.0, (-(_dragOffset.dx) / (_screenSize.width * 0.3)))
        .clamp(0.0, 1.0);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _dragAngle,
          child: Container(
            margin: const EdgeInsets.all(AppDimens.lg),
            height:
                _screenSize.height *
                0.35, // Reduced from 0.5 to show more "Up Next" items
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: radius,
              boxShadow: tokens?.neumorphicShadow,
            ),
            child: Stack(
              children: [
                _TrackCardContent(
                  trackTitle: widget.trackTitle,
                  artistName: widget.artistName,
                  score: widget.score,
                  imageUrl: widget.imageUrl,
                  borderRadius: radius,
                ),
                if (likeOpacity > 0)
                  _SwipeOverlay(
                    opacity: likeOpacity,
                    color: Colors.green,
                    icon: Icons.thumb_up_rounded,
                    borderRadius: radius,
                  ),
                if (dislikeOpacity > 0)
                  _SwipeOverlay(
                    opacity: dislikeOpacity,
                    color: Colors.red,
                    icon: Icons.thumb_down_rounded,
                    borderRadius: radius,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeableTrackCardArtwork extends StatelessWidget {
  final String imageUrl;

  const _SwipeableTrackCardArtwork({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasArtwork = imageUrl.isNotEmpty && imageUrl != 'placeholder';

    Widget fallback() => Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
      child: const Icon(Icons.music_note, size: 80, color: Colors.grey),
    );

    if (hasArtwork) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallback(),
      );
    }

    return fallback();
  }
}

class _TrackCardContent extends StatelessWidget {
  final String trackTitle;
  final String artistName;
  final int score;
  final String imageUrl;
  final BorderRadius borderRadius;

  const _TrackCardContent({
    required this.trackTitle,
    required this.artistName,
    required this.score,
    required this.imageUrl,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Column(
        children: [
          Expanded(child: _SwipeableTrackCardArtwork(imageUrl: imageUrl)),
          Container(
            padding: const EdgeInsets.all(AppDimens.lg),
            width: double.infinity,
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.xs),
                      Text(
                        artistName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: Text(
                    '$score votes',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
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

class _SwipeOverlay extends StatelessWidget {
  final double opacity;
  final Color color;
  final IconData icon;
  final BorderRadius borderRadius;

  const _SwipeOverlay({
    required this.opacity,
    required this.color,
    required this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity * 0.3),
          borderRadius: borderRadius,
        ),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: opacity,
          child: Icon(icon, size: 100, color: color.withValues(alpha: opacity)),
        ),
      ),
    );
  }
}

/// Helper section to render the card alongside traditional buttons
class DualModeVotingInterface extends StatefulWidget {
  const DualModeVotingInterface({super.key});

  @override
  State<DualModeVotingInterface> createState() =>
      _DualModeVotingInterfaceState();
}

class _DualModeVotingInterfaceState extends State<DualModeVotingInterface> {
  // Using a GlobalKey to trigger swipe from buttons
  final GlobalKey<SwipeableTrackCardState> _cardKey =
      GlobalKey<SwipeableTrackCardState>();

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final activeEvent = eventsProvider.selectedEvent;

    if (activeEvent == null || activeEvent.tracks.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No tracks available for voting')),
      );
    }

    // * Filter out tracks we have already voted on in this session
    final unvotedTracks = activeEvent.tracks
        .where((t) => !eventsProvider.votedTrackIds.contains(t.id))
        .toList();

    if (unvotedTracks.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No tracks available for voting')),
      );
    }

    // * Show the first unvoted track in the voting interface
    final track = unvotedTracks.first;

    Future<void> handleVote(SwipeAction action) async {
      final value = action == SwipeAction.like ? 1 : -1;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        await eventsProvider.voteForTrack(activeEvent.id, track.id, value);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              value > 0
                  ? 'Voted UP for ${track.title}!'
                  : 'Voted DOWN for ${track.title}!',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      } catch (_) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(eventsProvider.error ?? 'Could not cast vote.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    return Column(
      children: [
        // 1. The Swipeable Card
        SwipeableTrackCard(
          key: _cardKey,
          trackTitle: track.title,
          artistName: track.artist,
          score: track.score,
          imageUrl: track.artworkUrl ?? "placeholder",
          onSwiped: handleVote,
        ),

        const SizedBox(height: AppDimens.lg),

        // 2. Traditional Buttons (triggering the same physics animation)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            NeumorphicInteractiveContainer(
              onTap: () => _cardKey.currentState?.triggerDislike(),
              padding: const EdgeInsets.all(AppDimens.xl),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Icon(
                Icons.close_rounded,
                size: 36,
                color: Colors.red,
              ),
            ),
            NeumorphicInteractiveContainer(
              onTap: () => _cardKey.currentState?.triggerLike(),
              padding: const EdgeInsets.all(AppDimens.xl),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Icon(
                Icons.favorite_rounded,
                size: 36,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
