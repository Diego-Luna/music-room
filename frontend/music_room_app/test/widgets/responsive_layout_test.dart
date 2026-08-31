import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/core/repositories/friends_repository.dart';
import 'package:music_room_app/core/repositories/room_repository.dart';
import 'package:music_room_app/pages/main/pages/main_screen.dart';
import 'package:music_room_app/providers/navigation_provider.dart';
import 'package:music_room_app/providers/notifications_provider.dart';
import 'package:music_room_app/widgets/responsive_body.dart';
import 'package:music_room_app/widgets/responsive_navbar.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late NavigationProvider navigation;
  late NotificationsProvider notifications;

  setUp(() {
    navigation = NavigationProvider();
    notifications = NotificationsProvider(
      roomRepository: MockRoomRepository(),
      friendsRepository: MockFriendsRepository(),
    );
  });

  Widget harness({required Size size, required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<NavigationProvider>.value(value: navigation),
            ChangeNotifierProvider<NotificationsProvider>.value(
              value: notifications,
            ),
          ],
          child: child,
        ),
      ),
    );
  }

  testWidgets('compact width uses a bottom navigation bar', (tester) async {
    await tester.pumpWidget(
      harness(
        size: const Size(390, 844),
        child: const MainPage(child: Text('body')),
      ),
    );

    expect(find.byType(NavigationBar), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    expect(find.text('Music Room'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('wide width uses a top navigation bar', (tester) async {
    await tester.pumpWidget(
      harness(
        size: const Size(1200, 800),
        child: const MainPage(child: Text('body')),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNull);
    expect(find.text('Music Room'), findsOneWidget);
    expect(find.byType(ResponsiveNavbar), findsOneWidget);
  });

  test('AppBreakpoints.compact is the documented 700 px cut', () {
    expect(AppBreakpoints.compact, 700);
  });

  testWidgets('ResponsiveBody caps width on a wide window', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const probe = Key('probe');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveBody(
            child: ColoredBox(key: probe, color: Colors.red),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(probe));
    expect(box.size.width, AppBreakpoints.content);
  });
}
