import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Grab a playlist track and drag it to a new position.
///
/// A mouse or trackpad starts the drag as soon as the pointer moves, so the
/// row can still be clicked to play. A finger starts it after a short press,
/// so a swipe keeps scrolling the list.
class TrackReorderGesture extends StatelessWidget {
  const TrackReorderGesture({
    super.key,
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: enabled ? (event) => _start(context, event) : null,
      child: child,
    );
  }

  void _start(BuildContext context, PointerDownEvent event) {
    final list = SliverReorderableList.maybeOf(context);
    if (list == null) return;
    final direct =
        event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad;
    final MultiDragGestureRecognizer recognizer = direct
        ? ImmediateMultiDragGestureRecognizer(debugOwner: this)
        : DelayedMultiDragGestureRecognizer(debugOwner: this);
    list.startItemDragReorder(
      index: index,
      event: event,
      recognizer: recognizer
        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
    );
  }
}
