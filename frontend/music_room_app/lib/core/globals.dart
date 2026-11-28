import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The router's root Navigator. Overlays opened from outside the page tree
/// (the MaterialApp builder) need its context: the ScaffoldMessenger sits
/// above the Navigator and cannot push routes.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
