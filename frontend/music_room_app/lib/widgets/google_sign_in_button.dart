import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/animations/neumorphic_interactive_container.dart';

// * Conditional import: on web loads the real renderButton() implementation;
// * on native loads a stub that throws UnsupportedError (never called at runtime
// * because the web branch is guarded by kIsWeb).
import 'google_sign_in_render_button_web.dart'
    if (dart.library.io) 'google_sign_in_render_button_stub.dart';

/// Cross-platform Google Sign-In button.
///
/// Web: renders the official GIS button via [renderButton()] from
///   [GoogleSignInPlugin]. The user clicks it, the GIS SDK,
///   The resolved access token is forwarded via [onTokenReceived].
/// Native: a styled tap target that calls
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Future<void> Function(String accessToken) onTokenReceived;
  final TextStyle? labelStyle;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    required this.onTokenReceived,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _WebGoogleButton(onTokenReceived: onTokenReceived);
    }
    return _NativeGoogleButton(onPressed: onPressed, labelStyle: labelStyle);
  }
}

// ! Web — uses GoogleSignInPlugin.renderButton() from google_sign_in_web.

class _WebGoogleButton extends StatefulWidget {
  final Future<void> Function(String accessToken) onTokenReceived;
  const _WebGoogleButton({required this.onTokenReceived});

  @override
  State<_WebGoogleButton> createState() => _WebGoogleButtonState();
}

class _WebGoogleButtonState extends State<_WebGoogleButton> {
  // * Kept to allow cancellation; dynamic avoids web-only type references.
  dynamic _subscription;

  @override
  void initState() {
    super.initState();
    // * authenticationEvents stream fires when the user completes the GIS popup.
    _subscription = GoogleSignIn.instance.authenticationEvents.listen(
      _onAuthEvent,
      onError: (Object err) {
        debugPrint('[GoogleSignIn][Web] stream error: $err');
      },
    );
  }

  Future<void> _onAuthEvent(GoogleSignInAuthenticationEvent event) async {
    debugPrint('[GoogleSignIn][Web] event: ${event.runtimeType}');

    // * GoogleSignInAuthenticationEventSignIn carries the signed-in user.
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    try {
      debugPrint(
        '[GoogleSignIn][Web] Requesting scopes for ${event.user.email}...',
      );
      final clientAuth = await event.user.authorizationClient.authorizeScopes(
        const ['email', 'profile'],
      );
      debugPrint('[GoogleSignIn][Web] Scopes granted.');

      final token = clientAuth.accessToken;

      debugPrint('[GoogleSignIn][Web] Token obtained, forwarding to provider.');
      await widget.onTokenReceived(token);
    } on Exception catch (e) {
      debugPrint('[GoogleSignIn][Web] Exception during scope request: $e');
    }
  }

  @override
  void dispose() {
    // ignore: avoid_dynamic_calls
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDesignTokens>();

    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        boxShadow: tokens?.neumorphicShadow,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 0.5),
      ),
      child: buildGoogleRenderButton(),
    );
  }
}

// * Simple styled tap target.

class _NativeGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final TextStyle? labelStyle;
  const _NativeGoogleButton({this.onPressed, this.labelStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NeumorphicInteractiveContainer(
      onTap: onPressed,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.g_mobiledata, size: 30),
          const SizedBox(width: AppDimens.sm),
          Text(
            'Google',
            style: (labelStyle ?? theme.textTheme.bodyLarge)?.copyWith(
              fontWeight: AppTypography.semibold,
            ),
          ),
        ],
      ),
    );
  }
}
