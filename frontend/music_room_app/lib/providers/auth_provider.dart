import 'package:flutter/foundation.dart';

//* Skeleton auth provider
//  ! is not funcional
class AuthProvider extends ChangeNotifier {
  bool _signedIn = false;

  bool get signedIn => _signedIn;

  Future<void> signInPlaceholder() async {
    // Placeholder: simulate async sign-in
    await Future.delayed(const Duration(milliseconds: 200));
    _signedIn = true;
    notifyListeners();
  }

  Future<void> signOutPlaceholder() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _signedIn = false;
    notifyListeners();
  }
}
