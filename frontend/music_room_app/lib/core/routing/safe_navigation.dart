import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/core/routing/route_names.dart';

// * Extension for safe navigation operations.
extension SafeNavigationExtension on BuildContext {
  /// This prevents GoRouter's `There is nothing to pop` exception when users
  /// access screens via direct URLs, deep links, or after route replacement.
  void safePop({String fallbackRoute = routeHome}) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }
}
