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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.login(_emailController.text.trim(), _passwordController.text);

    if (mounted) {
      if (auth.signedIn) {
        context.go(routeHome);
      } else if (auth.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(), // No back button on login
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
                  const SizedBox(height: AppDimens.xl),
                  Text(
                    'Welcome to\nMusic Room',
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Text(
                    'Sign in to sync your playlists, join rooms and vote live.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: AppDimens.xxl * 2),

                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            hintText: 'Email address',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                          ),
                          const SizedBox(height: AppDimens.lg),
                          AuthTextField(
                            hintText: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passwordController,
                          ),

                          const SizedBox(height: AppDimens.lg),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Forgot Password?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppDimens.xxl),

                          PrimaryButton(
                            label: 'Sign In',
                            isLoading: auth.isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppDimens.xxl),
                  Center(
                    child: Text(
                      'Or continue with',
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
                          onTap: _handleLogin,
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
                          onTap: _handleLogin,
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
                        "Don't have an account? ",
                        style: theme.textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => context.go(routeSignup),
                        child: Text(
                          "Sign Up",
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
