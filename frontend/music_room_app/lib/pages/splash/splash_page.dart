import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room_app/theme/app_theme.dart';
import 'package:music_room_app/helper/animations/fade_animation.dart';
import 'package:music_room_app/helper/animations/scale_animation.dart';
import 'package:music_room_app/helper/animations/motion_shapes.dart';
import 'package:music_room_app/routes/route_names.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _showName1 = false;
  bool _showName2 = false;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Stagger the appearance of the creators' names to mimic the original timeline.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _showName1 = true);
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _showName2 = true);
    });

    // Navigate to main screen after a short delay (gives time to appreciate animation).
    _navTimer = Timer(const Duration(milliseconds: 4200), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, routeMain);
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title: scale + fade
            ScaleIn(
              begin: 0.85,
              duration: const Duration(milliseconds: 700),
              child: FadeIn(
                duration: const Duration(milliseconds: 700),
                child: Text(
                  'Music Room',
                  style: TextStyle(
                    fontSize: AppTypography.h1,
                    fontWeight: AppTypography.extraBold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppDimens.xxl),

            // Creators names (staggered)
            if (_showName1) ...[
              FadeIn(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Diego',
                  style: TextStyle(
                    fontSize: AppTypography.h5,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.sm),
            ],

            if (_showName2) ...[
              FadeIn(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Jeremy',
                  style: TextStyle(
                    fontSize: AppTypography.h5,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppDimens.xl),

            // Decorative motion shapes
            const MotionShapes(size: 10.0, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
