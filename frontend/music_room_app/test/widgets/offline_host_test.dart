import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/offline_host.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.online);

  bool online;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      online ? [ConnectivityResult.wifi] : [ConnectivityResult.none];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows the offline banner when there is no network', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OfflineHost(
          connectivity: _FakeConnectivity(false),
          child: const Text('body'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_banner')), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('hides the banner when online', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OfflineHost(
          connectivity: _FakeConnectivity(true),
          child: const Text('body'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_banner')), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });
}
