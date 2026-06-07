import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/config/hive_config.dart';
import 'package:music_room_app/core/globals.dart';

// * Builds the offline-sync notification: actions the server rejected on
// * reconnect, with their precise cause (vote session closed, item deleted…).
void _notifyRejectedSync(List<SyncDiscard> rejected) {
  if (rejected.isEmpty) return;
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final text = rejected.length == 1
      ? '${rejected.first.label} not synced — ${rejected.first.reason}'
      : '${rejected.length} changes not synced — e.g. ${rejected.first.label}: ${rejected.first.reason}';
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
}

void main() async {
  setUrlStrategy(HashUrlStrategy());
  WidgetsFlutterBinding.ensureInitialized();

  setupLocator();
  await HiveConfig.initialize();
  syncManager.startMonitoring();
  syncManager.discards.listen(_notifyRejectedSync);
  await authProvider.tryAutoLogin();

  // * Register/refresh the device push token whenever the session changes.
  // Best-effort bonus feature — never blocks startup or auth.
  // Unregistration runs via onBeforeLogout (below) while the bearer is still
  // valid; the listener only needs to (re)register on sign-in.
  authProvider.onBeforeLogout = pushTokenService.unregister;
  authProvider.addListener(() {
    if (authProvider.signedIn) {
      pushTokenService.registerIfNeeded();
    } else {
      pushTokenService.reset();
    }
  });
  if (authProvider.signedIn) {
    pushTokenService.registerIfNeeded();
  }

  runApp(const AppState());
}

class AppState extends StatelessWidget {
  const AppState({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: navigationProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: eventsProvider),
        ChangeNotifierProvider.value(value: playlistsProvider),
        ChangeNotifierProvider.value(value: roomsProvider),
        ChangeNotifierProvider.value(value: friendsProvider),
        ChangeNotifierProvider.value(value: notificationsProvider),
        ChangeNotifierProvider.value(value: playerProvider),
        ChangeNotifierProvider.value(value: socketProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp.router(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'Music Room',
            routerConfig: AppRouter.router,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
          );
        },
      ),
    );
  }
}
