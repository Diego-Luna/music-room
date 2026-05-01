import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/widgets/interactive_3d/daft_punk_loader.dart';
import 'package:music_room_app/widgets/interactive_3d/floating_music_entities.dart';
import 'package:music_room_app/widgets/primary_button.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Background 3D Floaters
          const BackgroundFloaters(),

          // 2. Overlay Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                child: SizedBox(
                  height:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppDimens.xxl * 2),

                      // Brand Logo / Title
                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Text(
                          'MUSIC\nROOM',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: AppTypography.extraBold,
                            letterSpacing: 4.0,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimens.md),

                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Text(
                          'Social Listening Experience...',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            letterSpacing: 1.2,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                      ),

                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Text(
                          '42Paris',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            letterSpacing: 1.2,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                      ),

                      // 3D Loader
                      const DaftPunkLoader(size: 300),

                      // creators names
                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Text(
                          'Diego',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            letterSpacing: 1.2,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                      ),

                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Text(
                          'Jeremy',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            letterSpacing: 1.2,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                      ),

                      const Spacer(),

                      FadeIn(
                        duration: const Duration(seconds: 1),
                        child: Column(
                          children: [
                            PrimaryButton(
                              label: 'Get Started',
                              onPressed: () => context.push(routeLogin),
                            ),
                            const SizedBox(height: AppDimens.lg),
                            TextButton(
                              onPressed: () {
                                // Todo: move to the repository on github
                                // https://github.com/Diego-Luna/music-room
                                // use the browser to open the repository
                              },
                              child: Text(
                                'Learn More',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: AppTypography.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimens.xl),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
