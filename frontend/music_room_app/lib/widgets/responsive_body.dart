import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

/// Caps content width and centers it. On a phone the max is larger than the
/// screen so the layout is unchanged; on desktop the column doesn't stretch
/// to 1920 px (VI.1 "adapt to any screen size").
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.content,
  });

  const ResponsiveBody.form({super.key, required this.child})
    : maxWidth = AppBreakpoints.form;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // * Fill the shell when the parent gives a height. Inside a scroll
        // * view the height is unbounded and the child keeps its own size.
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : null;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
