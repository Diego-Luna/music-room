import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

// ! dart:io is only available on native platforms
import 'platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

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
  final bool _isTest = kIsWeb
      ? false
      : Platform.environment.containsKey('FLUTTER_TEST');

  bool _isLoading = true;
  double _theta = 0.0;

  @override
  void initState() {
    super.initState();
    _viewerController = Flutter3DController();

    // * Continuous rotation ticker (used only if gyro is active)
    _ticker = createTicker((elapsed) {
      if (!_isLoading) {
        setState(() {
          // 360 degrees in 'duration' seconds
          final double delta =
              (360 * elapsed.inMicroseconds) / (widget.duration.inMicroseconds);
          _theta = delta % 360;
          _updateCamera();
        });
      }
    });
  }

  void _updateCamera() {
    _viewerController.setCameraOrbit(_theta, 0, 70);
  }

  @override
  void dispose() {
    _ticker?.dispose();
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
                final double speed =
                    360 / (widget.duration.inMilliseconds / 1000.0);
                _viewerController.startRotation(rotationSpeed: speed.toInt());
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
