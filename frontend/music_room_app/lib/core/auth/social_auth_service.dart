import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum SocialProvider { google, facebook }

extension SocialProviderApi on SocialProvider {
  /// Value expected by the backend (`/auth/social` DTO: 'google' | 'facebook').
  String get apiValue => this == SocialProvider.google ? 'google' : 'facebook';

  String get label => this == SocialProvider.google ? 'Google' : 'Facebook';
}

/// Runs the native OAuth flow for a provider and returns the **OAuth access
/// token** the backend validates (Google: oauth2 userinfo + tokeninfo audience
/// check; Facebook: graph debug_token).
///
/// Kept behind an interface so [AuthProvider] stays unit-testable (tests inject
/// a fake) and the provider SDKs are isolated in one place.
abstract class SocialAuthService {
  /// Runs the native sign-in for [provider] and returns its access token,
  /// or `null` if the user cancelled the flow.
  Future<String?> signIn(SocialProvider provider);

  /// Clears cached native sessions so the next sign-in re-prompts.
  Future<void> signOut();
}

class DefaultSocialAuthService implements SocialAuthService {
  final GoogleSignIn _google;
  final FacebookAuth _facebook;

  DefaultSocialAuthService({GoogleSignIn? google, FacebookAuth? facebook})
    : _google = google ?? GoogleSignIn.instance,
      _facebook = facebook ?? FacebookAuth.instance;

  @override
  Future<String?> signIn(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.google:
        return _signInGoogle();
      case SocialProvider.facebook:
        return _signInFacebook();
    }
  }

  Future<String?> _signInGoogle() async {
    // ! authenticate() is not supported on Web — callers must use
    // ! GoogleSignInWebButton widget instead and listen to authenticationEvents.
    if (kIsWeb) {
      debugPrint(
        '[GoogleSignIn] Web: authenticate() is unsupported. '
        'Use GoogleSignInWebButton in the UI instead.',
      );
      return null;
    }

    debugPrint('[GoogleSignIn] Starting native sign-in flow...');
    try {
      debugPrint('[GoogleSignIn] Calling _google.authenticate()...');
      final account = await _google.authenticate();
      debugPrint(
        '[GoogleSignIn] authenticate() OK — account: ${account.email}',
      );

      // * Prefer idToken directly (no extra consent dialog on iOS/Android).
      final idToken = account.authentication.idToken;
      if (idToken != null && idToken.isNotEmpty) {
        debugPrint(
          '[GoogleSignIn] ID token obtained (length: ${idToken.length}).',
        );
        return idToken;
      }

      debugPrint('[GoogleSignIn] Requesting scopes [email, profile]...');
      final clientAuth = await account.authorizationClient.authorizeScopes(
        const ['email', 'profile'],
      );
      debugPrint('[GoogleSignIn] authorizeScopes() OK.');

      final token = clientAuth.accessToken;
      debugPrint('[GoogleSignIn] Token obtained (length: ${token.length}).');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[GoogleSignIn] Cancelled by user.');
        return null;
      }
      debugPrint('[GoogleSignIn] GoogleSignInException: ${e.code} — $e');
      throw Exception(e.description ?? 'Google sign-in failed (${e.code.name})');
    } catch (e) {
      debugPrint('[GoogleSignIn] Unexpected error: ${e.runtimeType} — $e');
      rethrow;
    }
  }

  Future<String?> _signInFacebook() async {
    debugPrint('[FacebookSignIn] Starting sign-in flow...');
    final result = await _facebook.login(
      permissions: const ['email', 'public_profile'],
      loginTracking: LoginTracking.enabled,
    );
    debugPrint('[FacebookSignIn] Result status: ${result.status}');
    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        debugPrint('[FacebookSignIn] Success — token length: ${token?.length}');
        return token;
      case LoginStatus.cancelled:
        debugPrint('[FacebookSignIn] Cancelled by the user.');
        return null;
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        debugPrint('[FacebookSignIn] Failed: ${result.message}');
        throw Exception(result.message ?? 'Facebook login failed');
    }
  }

  @override
  Future<void> signOut() async {
    debugPrint('[SocialAuthService] Signing out from Google and Facebook...');
    await _google.signOut();
    await _facebook.logOut();
    debugPrint('[SocialAuthService] Sign-out complete.');
  }
}
