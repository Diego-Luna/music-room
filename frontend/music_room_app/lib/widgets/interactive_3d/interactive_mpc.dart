import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

/// Interactive 3D widget for the MPC ONE+
// ! is not interactive yet
// TODO: make it interactive with the 5 interactive objects

class InteractiveMpc extends StatefulWidget {
  final VoidCallback? onPadInteraction;

  const InteractiveMpc({super.key, this.onPadInteraction});

  @override
  State<InteractiveMpc> createState() => _InteractiveMpcState();
}

class _InteractiveMpcState extends State<InteractiveMpc> {
  final Flutter3DController _controller = Flutter3DController();
  final bool _isTest = kIsWeb
      ? false
      : Platform.environment.containsKey('FLUTTER_TEST');

  /// Simulates Raycasting/Hitboxes.c
  /// hitboxes over the 3D rendering stack.
  void _onPadPressed(int padIndex) {
    // Haptic feedback to emulate the feel of a real physical pad.
    HapticFeedback.mediumImpact();
    // Execute whatever the app needs (e.g., adding a beat to a playlist)
    widget.onPadInteraction?.call();

    // Skip controller animations in test environment as there's no 3D model loaded
    if (_isTest) return;

    // Subtly animate the camera to give a pulse or punch sensation.
    // Tighter values for more visual impact (e.g. from 70 to 60)
    _controller.setCameraOrbit(15, 10, 60);
    Future.delayed(const Duration(milliseconds: 200), () {
      _controller.setCameraOrbit(0, 0, 70);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag:
          'interactive-mpc-hero', // Hero Transformation to the screen that opens it
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: 600, // Increased height to show the MPC better
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // The 3D engine rendering layer
                  SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: _isTest
                        ? const Center(
                            key: Key('3d_placeholder_mpc'),
                            child: Icon(Icons.apps),
                          )
                        : Flutter3DViewer(
                            controller: _controller,
                            src: kIsWeb
                                ? 'assets/assets/models/interactive/mpc_one.glb'
                                : 'assets/models/interactive/mpc_one.glb',
                            onLoad: (modelAddress) {
                              // Making the model slightly larger by default and aligning it to zoom=70
                              _controller.setCameraOrbit(0, 0, 70);
                            },
                          ),
                  ),

                  // Grid scaled according to the new visual size
                  Positioned(
                    bottom: 80, // Moved up to match the new height
                    left: 0,
                    right: 0,
                    height: 200,
                    child: Center(
                      child: IntrinsicWidth(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: List.generate(16, (index) {
                            return GestureDetector(
                              onTapDown: (_) => _onPadPressed(index),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors
                                    .transparent, // Transparent in production
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
