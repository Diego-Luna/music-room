import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;

  const AudioVisualizer({super.key, required this.isPlaying});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final int _barCount = 15;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _barCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + _random.nextInt(300)),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.1,
        end: 0.8 + _random.nextDouble() * 0.2,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    for (var controller in _controllers) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller.reverse();
        } else if (status == AnimationStatus.dismissed && widget.isPlaying) {
          controller.forward();
        }
      });
    }

    if (widget.isPlaying) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startAnimations();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && widget.isPlaying) {
          _controllers[i].forward();
        }
      });
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.animateTo(0.1, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 40 * _animations[index].value,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
