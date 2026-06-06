import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum SocialProvider { google, facebook }

extension SocialProviderApi on SocialProvider {
  /// Value expected by the backend (`/auth/social` DTO: 'google' | 'facebook').
  String get apiValue =>
      this == SocialProvider.google ? 'google' : 'facebook';

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
    : _google = google ?? GoogleSignIn(scopes: const ['email', 'profile']),
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
    final account = await _google.signIn();
    if (account == null) return null; // cancelled
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<String?> _signInFacebook() async {
    final result = await _facebook.login(
      permissions: const ['email', 'public_profile'],
    );
    switch (result.status) {
      case LoginStatus.success:
        return result.accessToken?.tokenString;
      case LoginStatus.cancelled:
        return null;
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw Exception(result.message ?? 'Facebook login failed');
    }
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    await _facebook.logOut();
  }
}
