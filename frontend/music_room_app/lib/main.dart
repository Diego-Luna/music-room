import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/config/hive_config.dart';
import 'package:music_room_app/core/globals.dart';

void main() async {
  setUrlStrategy(HashUrlStrategy());
  WidgetsFlutterBinding.ensureInitialized();

  setupLocator();
  await HiveConfig.initialize();
  syncManager.startMonitoring();
  await authProvider.tryAutoLogin();

  // * Register/refresh the device push token whenever the session changes.
  // Best-effort bonus feature — never blocks startup or auth.
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
