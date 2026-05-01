import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

/// I needed a 3D model that floats smoothly with a neumorphic vibe.
/// which makes the background feel alive but not distracting.
class FloatingModel extends StatefulWidget {
  final String modelPath;
  final double size;
  final double rotationSpeed;

  const FloatingModel({
    super.key,
    required this.modelPath,
    this.size = 100.0,
    this.rotationSpeed = 20.0,
  });

  @override
  State<FloatingModel> createState() => _FloatingModelState();
}

class _FloatingModelState extends State<FloatingModel> {
  late final Flutter3DController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Flutter3DController();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Flutter3DViewer(
        controller: _controller,
        src: widget.modelPath,
        onLoad: (modelAddress) {
          // * Start native rotation using the controller
          _controller.startRotation(
            rotationSpeed: widget.rotationSpeed.toInt(),
          );
        },
      ),
    );
  }
}

/// A simple Stack wrapping my multiple music models.
/// I use this to add depth to any background screen.
class BackgroundFloaters extends StatelessWidget {
  const BackgroundFloaters({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(
          top: 100,
          left: 30,
          child: FloatingModel(
            modelPath: 'assets/models/background/musical_note.glb',
            size: 80,
            rotationSpeed: 15.0,
          ),
        ),
        Positioned(
          top: 300,
          right: 20,
          child: FloatingModel(
            modelPath: 'assets/models/background/guitar_model.glb',
            size: 120,
            rotationSpeed: 25.0,
          ),
        ),
        Positioned(
          bottom: 150,
          left: 50,
          child: FloatingModel(
            modelPath: 'assets/models/background/saxophone.glb',
            size: 90,
            rotationSpeed: 10.0,
          ),
        ),
      ],
    );
  }
}
