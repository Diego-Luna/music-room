import 'package:flutter/material.dart';

//* Simple FadeIn implicit animation widget.
// ! the simply animation
class FadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginOpacity;

  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeIn,
    this.beginOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginOpacity, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }
}
