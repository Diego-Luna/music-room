import 'package:flutter/material.dart';

// * Simple decorative motion shapes (implicit tweens).
// ! Not critical — used as a small visual helper for placeholders.
class MotionShapes extends StatelessWidget {
  final double size;
  final Color color;
  final Duration duration;

  const MotionShapes({
    super.key,
    this.size = 12.0,
    this.color = Colors.white24,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1.0),
          duration: duration + Duration(milliseconds: i * 120),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: size,
                height: size,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
