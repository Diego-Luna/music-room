import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';
import 'package:music_room_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/auth_provider.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _isLoading = false;

  void _handleSignup() async {
    setState(() => _isLoading = true);

    // Simulate network delay and login
    final auth = context.read<AuthProvider>();
    await auth.signInPlaceholder();

    if (mounted) {
      setState(() => _isLoading = false);
      context.go(routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.primary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: FadeIn(
            duration: const Duration(milliseconds: 600),
            child: SlideIn(
              beginOffset: const Offset(0, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimens.md),
                  Text('Create Account', style: theme.textTheme.displayLarge),
                  const SizedBox(height: AppDimens.sm),
                  Text(
                    'Join Music Room to collaborate on playlists and vote on live tracks.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: AppDimens.xxl * 2),

                  const AuthTextField(
                    hintText: 'Display Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppDimens.lg),
                  const AuthTextField(
                    hintText: 'Email address',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: AppDimens.lg),
                  const AuthTextField(
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),

                  const SizedBox(height: AppDimens.xxl),

                  PrimaryButton(
                    label: 'Sign Up',
                    isLoading: _isLoading,
                    onPressed: _handleSignup,
                  ),

                  const SizedBox(height: AppDimens.xxl),
                  Center(
                    child: Text(
                      'Or sign up with',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),

                  Row(
                    children: [
                      Expanded(
                        child: NeumorphicInteractiveContainer(
                          onTap: _handleSignup,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.md,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.g_mobiledata, size: 30),
                              const SizedBox(width: AppDimens.sm),
                              Text(
                                'Google',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: AppTypography.semibold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.lg),
                      Expanded(
                        child: NeumorphicInteractiveContainer(
                          onTap: _handleSignup,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMedium,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.md,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.facebook, color: Colors.blue),
                              const SizedBox(width: AppDimens.sm),
                              Text(
                                'Facebook',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: AppTypography.semibold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimens.xxl * 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: theme.textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => context.go(routeLogin),
                        child: Text(
                          "Sign In",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
