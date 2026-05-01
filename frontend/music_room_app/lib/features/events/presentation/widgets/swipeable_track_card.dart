import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

enum SwipeAction { like, dislike, none }

// ! A Tinder-style swipeable card for track voting.
class SwipeableTrackCard extends StatefulWidget {
  final String trackTitle;
  final String artistName;
  final String imageUrl;
  final Function(SwipeAction) onSwiped;

  const SwipeableTrackCard({
    super.key,
    required this.trackTitle,
    required this.artistName,
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

  // Size of the screen determines limits
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          setState(() {});
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
    final startOffset = _dragOffset;
    final startAngle = _dragAngle;

    //* Are we escaping the screen or snapping back to the center?
    final isEscaping = targetOffset != Offset.zero;

    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        // If escaping (swipe successful), we use an easeOut for a smooth exit.
        // If rebouncing (snap back), we use an elastic spring for a physics-based simulation feel!
        curve: isEscaping ? Curves.easeOut : Curves.elasticOut,
      ),
    );

    animation.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, targetOffset, animation.value)!;
        _dragAngle =
            ui.lerpDouble(
              startAngle,
              isEscaping ? startAngle : 0.0,
              animation.value,
            ) ??
            0.0;
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (action != SwipeAction.none) {
          widget.onSwiped(action);
          // Optional: reset state if the card is to be reused immediately
          _dragOffset = Offset.zero;
          _dragAngle = 0.0;
        }
      }
    });

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

    // Calculate background colors based on drag
    double likeOpacity = math
        .max(0.0, (_dragOffset.dx / (_screenSize.width * 0.3)))
        .clamp(0.0, 1.0);
    double dislikeOpacity = math
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
              borderRadius:
                  tokens?.cardRadius ??
                  BorderRadius.circular(AppDimens.radiusLarge),
              boxShadow: tokens?.neumorphicShadow,
            ),
            child: Stack(
              children: [
                // 1. The Main Content (Album art placeholder + info)
                ClipRRect(
                  borderRadius:
                      tokens?.cardRadius ??
                      BorderRadius.circular(AppDimens.radiusLarge),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                          ),
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
                              widget.trackTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppDimens.xs),
                            Text(
                              widget.artistName,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Visual overlays for Swiping (LIKE)
                if (likeOpacity > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(
                          alpha: likeOpacity * 0.3,
                        ),
                        borderRadius:
                            tokens?.cardRadius ??
                            BorderRadius.circular(AppDimens.radiusLarge),
                      ),
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scale: likeOpacity,
                        child: Icon(
                          Icons.thumb_up_rounded,
                          size: 100,
                          color: Colors.green.withValues(alpha: likeOpacity),
                        ),
                      ),
                    ),
                  ),

                // 3. Visual overlays for Swiping (DISLIKE)
                if (dislikeOpacity > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(
                          alpha: dislikeOpacity * 0.3,
                        ),
                        borderRadius:
                            tokens?.cardRadius ??
                            BorderRadius.circular(AppDimens.radiusLarge),
                      ),
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scale: dislikeOpacity,
                        child: Icon(
                          Icons.thumb_down_rounded,
                          size: 100,
                          color: Colors.red.withValues(alpha: dislikeOpacity),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  void _handleVote(SwipeAction action) {
    if (action == SwipeAction.like) {
      // TODO: Call API provider to vote
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voted: LIKE'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (action == SwipeAction.dislike) {
      // TODO: Call API provider to skip
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voted: DISLIKE'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. The Swipeable Card
        SwipeableTrackCard(
          key: _cardKey,
          trackTitle: "Bohemian Rhapsody",
          artistName: "Queen",
          imageUrl: "placeholder",
          onSwiped: _handleVote,
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
