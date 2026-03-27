import 'package:flutter/material.dart';
import 'package:music_room_app/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _name1Opacity;
  late final Animation<double> _name2Opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );

    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _name1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.75, curve: Curves.easeIn),
      ),
    );

    _name2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 0.95, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          // move to main screen after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          });
        }
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: _titleOpacity.value,
                  child: Transform.scale(
                    scale: _titleScale.value,
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
                SizedBox(height: AppDimens.xxl),
                Opacity(
                  opacity: _name1Opacity.value,
                  child: Text(
                    'Diego',
                    style: TextStyle(
                      fontSize: AppTypography.h5,
                      color: Colors.white70,
                    ),
                  ),
                ),
                SizedBox(height: AppDimens.sm),
                Opacity(
                  opacity: _name2Opacity.value,
                  child: Text(
                    'Jeremy',
                    style: TextStyle(
                      fontSize: AppTypography.h5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
