import 'package:flutter/material.dart';

//* StaggeredList
// Cascading animation for our lists (Rooms, Playlists, etc.).
// It smoothly combines FadeIn and SlideIn with an incremental delay
// to create that premium, sequential loading feel.
class StaggeredList extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final Duration staggerDelay;
  final Offset beginOffset;

  const StaggeredList({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 75),
    this.beginOffset = const Offset(0, 30),
  });

  @override
  Widget build(BuildContext context) {
    // We calculate the total delay based on the index position
    final delay = staggerDelay * index;

    return FutureBuilder<bool>(
      future: Future.delayed(delay, () => true),
      initialData: false,
      builder: (context, snapshot) {
        // While waiting for our turn, we render an empty invisible box
        // so the layout doesn't break or jump.
        if (snapshot.data != true) {
          return Opacity(opacity: 0, child: child);
        }

        // Once the delay passes, we fire the combined implicit animations!
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: baseDuration,
          curve: Curves.easeOut,
          builder: (context, opacityValue, childWidget) {
            return TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(begin: beginOffset, end: Offset.zero),
              duration: baseDuration,
              curve: Curves.easeOutCubic,
              builder: (context, offsetValue, innerChild) {
                return Transform.translate(
                  offset: offsetValue,
                  child: Opacity(opacity: opacityValue, child: innerChild),
                );
              },
              child: childWidget,
            );
          },
          child: child,
        );
      },
    );
  }
}
