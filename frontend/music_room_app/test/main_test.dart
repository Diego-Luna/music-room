// Test to verify SocketProvider is registered in the MultiProvider tree
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/main.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/providers/socket_provider.dart';
import 'package:music_room_app/providers/subscription_provider.dart';

void main() {
  testWidgets('SocketProvider is registered in MultiProvider widget tree', (
    tester,
  ) async {
    // Initialize the service locator
    setupLocator();
    // Build the app
    await tester.pumpWidget(const AppState());
    // Find a BuildContext via a descendant widget (MaterialApp)
    final buildContext = tester.element(find.byType(MaterialApp));
    // Verify that the provider can be retrieved without throwing
    expect(Provider.of<SocketProvider>(buildContext, listen: false), isNotNull);
    expect(
      Provider.of<SubscriptionProvider>(buildContext, listen: false),
      isNotNull,
    );
  });
}
