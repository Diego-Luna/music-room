import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/fade_animation.dart';
import 'package:music_room_app/core/animations/slide_animation.dart';
import 'package:music_room_app/widgets/interactive_3d/daft_punk_loader.dart';
import 'package:music_room_app/pages/auth/widgets/auth_text_field.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/core/routing/route_names.dart';
import 'package:music_room_app/providers/auth_provider.dart';

class VerifyEmailPage extends StatefulWidget {
  final String? token;
  const VerifyEmailPage({super.key, this.token});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _emailController = TextEditingController();
  bool _localLoading = true;
  bool _isSuccess = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _startVerification() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _localLoading = false;
        _localError = 'No token provided in the verification link.';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyEmail(widget.token!);

    if (mounted) {
      setState(() {
        _localLoading = false;
        _isSuccess = success;
        _localError = auth.error;
      });
    }
  }

  void _handleResend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.resendVerification(email);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If the account exists, a new verification link has been sent.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error ?? 'Failed to resend verification email'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: FadeIn(
              duration: const Duration(milliseconds: 600),
              child: SlideIn(
                beginOffset: const Offset(0, 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Visibility(
                      visible: _localLoading,
                      maintainState: true,
                      child: Column(
                        children: [
                          const Center(child: DaftPunkLoader(size: 150)),
                          const SizedBox(height: AppDimens.xxl),
                          Text(
                            'Verifying your email...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppDimens.sm),
                          Text(
                            'Please wait while we confirm your email address.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_localLoading && _isSuccess) ...[
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: tokens?.neumorphicShadow,
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: theme.colorScheme.primary,
                            size: 60,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.xxl),
                      Text(
                        'Email Verified!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        'Your email address has been verified successfully. You can now log in.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: AppDimens.xxl * 2),
                      PrimaryButton(
                        label: 'Go to Sign In',
                        onPressed: () => context.go(routeLogin),
                      ),
                    ] else if (!_localLoading && !_isSuccess) ...[
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: tokens?.neumorphicShadow,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 60,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.xxl),
                      Text(
                        'Invalid or Expired Link',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        _localError ??
                            'This email verification link is invalid, expired, or has already been used.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: AppDimens.xxl * 1.5),
                      Text(
                        'Enter your email address below to receive a new verification link.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimens.lg),
                      AuthTextField(
                        hintText: 'Email address',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                      ),
                      const SizedBox(height: AppDimens.xl),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return PrimaryButton(
                            label: 'Resend Verification Link',
                            isLoading: auth.isLoading,
                            onPressed: _handleResend,
                          );
                        },
                      ),
                      const SizedBox(height: AppDimens.lg),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(routeLogin),
                          child: Text(
                            'Back to Sign In',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
