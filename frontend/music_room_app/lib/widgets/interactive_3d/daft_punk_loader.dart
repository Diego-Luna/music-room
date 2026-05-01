import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A loading widget that spins the Daft Punk helmet using native 3D rotation,
/// influenced by the phone's gyroscope with a fallback to pure native rotation.
class DaftPunkLoader extends StatefulWidget {
  final double size;
  final Duration duration;

  const DaftPunkLoader({
    super.key,
    this.size = 150.0,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<DaftPunkLoader> createState() => _DaftPunkLoaderState();
}

class _DaftPunkLoaderState extends State<DaftPunkLoader>
    with SingleTickerProviderStateMixin {
  late final Flutter3DController _viewerController;
  Ticker? _ticker;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final bool _isTest = kIsWeb
      ? false
      : Platform.environment.containsKey('FLUTTER_TEST');

  bool _isLoading = true;
  bool _gyroActive =
      false; // Becomes true when the first gyro event is successfully received
  double _theta = 0.0;
  double _gyroPhi = 0.0;
  double _gyroTheta = 0.0;

  @override
  void initState() {
    super.initState();
    _viewerController = Flutter3DController();

    // * Continuous rotation ticker (used only if gyro is active)
    _ticker = createTicker((elapsed) {
      if (!_isLoading && _gyroActive) {
        setState(() {
          // 360 degrees in 'duration' seconds
          final double delta =
              (360 * elapsed.inMicroseconds) / (widget.duration.inMicroseconds);
          _theta = delta % 360;
          _updateCamera();
        });
      }
    });

    _initGyro();
  }

  void _initGyro() {
    try {
      // Listen to gyroscope events
      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          if (!mounted || _isLoading) return;

          // First time we get a valid event, gyro is working!
          if (!_gyroActive) {
            _gyroActive = true;
            _viewerController
                .stopRotation(); // Stop the fallback native rotation
            if (!(_ticker?.isTicking ?? true)) {
              _ticker?.start();
            }
          }

          setState(() {
            // We use a small factor to make the movement subtle and responsive
            _gyroPhi = (_gyroPhi + event.x * 1.5).clamp(-30.0, 30.0);
            _gyroTheta = (_gyroTheta - event.y * 1.5).clamp(-40.0, 40.0);
            _updateCamera();
          });
        },
        onError: (error) {
          debugPrint('Gyroscope error: $error');
          _fallbackToNativeRotation();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint(
        'Gyroscope init failed (e.g. web/desktop without sensors): $e',
      );
      _fallbackToNativeRotation();
    }
  }

  void _fallbackToNativeRotation() {
    if (!mounted) return;
    _gyroActive = false;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    if (_ticker?.isTicking ?? false) {
      _ticker?.stop();
    }

    if (!_isLoading) {
      final double speed = 360 / (widget.duration.inMilliseconds / 1000.0);
      _viewerController.startRotation(rotationSpeed: speed.toInt());
    }
  }

  void _updateCamera() {
    // * Combine automatic rotation with gyroscope offsets
    // * Base phi is 0 (centered)
    _viewerController.setCameraOrbit(_theta + _gyroTheta, _gyroPhi, 70);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _gyroSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTest) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        key: const Key('3d_placeholder_loader'),
        child: const Center(child: Icon(Icons.view_in_ar)),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Flutter3DViewer(
            controller: _viewerController,
            src: kIsWeb
                ? 'assets/assets/models/loading/daft_punk_thomas_helmet_re-uploaded.glb'
                : 'assets/models/loading/daft_punk_thomas_helmet_re-uploaded.glb',
            onProgress: (double progress) {
              debugPrint('3D Model Loading: ${progress * 100}%');
            },
            onLoad: (String modelAddress) {
              debugPrint('3D Model Loaded: $modelAddress');
              if (mounted) {
                setState(() => _isLoading = false);

                // Either start the gyro ticker, or fallback to native rotation
                if (_gyroActive) {
                  _ticker?.start();
                } else {
                  final double speed =
                      360 / (widget.duration.inMilliseconds / 1000.0);
                  _viewerController.startRotation(rotationSpeed: speed.toInt());
                }
              }
            },
            onError: (String error) {
              debugPrint('3D Model Error: $error');
            },
          ),
        ),
        // * Fallback loading indicator
        if (_isLoading)
          SizedBox(
            width: widget.size / 2,
            height: widget.size / 2,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
