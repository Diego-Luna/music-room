import 'package:flutter/material.dart';

//* ScaleIn implicit animation.
// ! the simply animation
class ScaleIn extends StatelessWidget {
  final Widget child;
  final double begin;
  final Duration duration;
  final Curve curve;

  const ScaleIn({
    super.key,
    required this.child,
    this.begin = 0.9,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutBack,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }
}
