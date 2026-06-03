import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/auth_provider.dart';

class ResetPasswordPage extends StatefulWidget {
  //* Token comes from the email link query param (?token=...).
  //* Nullable so a user landing without one can still paste it in.
  final String? token;

  const ResetPasswordPage({super.key, this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _handleResetPassword() async {
    final token = _tokenController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (token.isEmpty) {
      _showError('The reset token is missing. Open the link from your email.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters long');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(token, password);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can now sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go(routeLogin);
    } else {
      _showError(auth.error ?? 'Password reset failed');
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
          onPressed: () => context.go(routeLogin),
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
                  Text('Reset Password', style: theme.textTheme.displayLarge),
                  const SizedBox(height: AppDimens.sm),
                  Text(
                    'Choose a new password for your account.',
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
                          const SizedBox(height: AppDimens.lg),
                          //* Shown only when the token wasn't passed via the
                          //* deep link, so the user can paste it manually.
                          if (widget.token == null) ...[
                            AuthTextField(
                              hintText: 'Reset token',
                              icon: Icons.vpn_key_outlined,
                              controller: _tokenController,
                            ),
                            const SizedBox(height: AppDimens.lg),
                          ],
                          AuthTextField(
                            hintText: 'New password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passwordController,
                          ),
                          const SizedBox(height: AppDimens.lg),
                          AuthTextField(
                            hintText: 'Confirm new password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _confirmController,
                          ),

                          const SizedBox(height: AppDimens.xxl),

                          PrimaryButton(
                            label: 'Update Password',
                            isLoading: auth.isLoading,
                            onPressed: _handleResetPassword,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppDimens.xxl * 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Back to ",
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
