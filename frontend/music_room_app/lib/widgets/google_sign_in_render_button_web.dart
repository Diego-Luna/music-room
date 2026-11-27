import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

// ! Returns the official GIS sign-in button widget
Widget buildGoogleRenderButton({bool continueLabel = false}) {
  // * On web, GoogleSignInPlatform.instance is registered as GoogleSignInPlugin
  // * by GoogleSignInPlugin.registerWith(). The cast is safe at runtime.
  return (GoogleSignInPlatform.instance as GoogleSignInPlugin).renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.standard,
      theme: GSIButtonTheme.outline,
      shape: GSIButtonShape.rectangular,
      size: GSIButtonSize.large,
      text: continueLabel ? GSIButtonText.continueWith : GSIButtonText.signin,
      minimumWidth: 160,
      locale: 'en',
    ),
  );
}
