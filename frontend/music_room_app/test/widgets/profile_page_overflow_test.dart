import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_room_app/models/user.dart';
import 'package:music_room_app/providers/auth_provider.dart';
import 'package:music_room_app/providers/profile_provider.dart';
import 'package:music_room_app/pages/profile/pages/profile_page.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockProfileProvider extends Mock implements ProfileProvider {}

void main() {
  group('ProfilePage Overflow Tests', () {
    testWidgets(
      'ProfilePage renders without RenderFlex overflow with long email and narrow constraints',
      (tester) async {
        tester.view.physicalSize = const Size(214, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuthProvider();
        final mockProfile = MockProfileProvider();
        final testUser = User(
          id: 'c8137351-a53b-4ce0-8bf1-2775f0a3ecad',
          email: 'diegofcolunalopez@gmail.com',
          displayName: 'Diego Luna',
          emailVerified: true,
          visibility: UserVisibility.public,
          musicPreferences: ['Rock', 'Electronic', 'Jazz'],
        );

        when(() => mockAuth.user).thenReturn(testUser);
        when(() => mockAuth.signedIn).thenReturn(true);
        when(() => mockAuth.isLoading).thenReturn(false);

        when(() => mockProfile.profile).thenReturn(testUser);
        when(() => mockProfile.isLoading).thenReturn(false);
        when(() => mockProfile.error).thenReturn(null);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuth,
            child: MaterialApp(home: ProfilePage(profileProvider: mockProfile)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Diego Luna'), findsOneWidget);
        expect(find.text('diegofcolunalopez@gmail.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
