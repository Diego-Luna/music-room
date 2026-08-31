import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/routing/app_router.dart';
import 'package:music_room_app/core/services/connectivity_sync_manager.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/providers/theme_provider.dart';
import 'package:music_room_app/config/hive_config.dart';
import 'package:music_room_app/config/api_config.dart';
import 'package:music_room_app/config/location_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:music_room_app/core/globals.dart';
import 'package:music_room_app/widgets/proximity_host.dart';
import 'package:music_room_app/widgets/offline_host.dart';

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

  // * Initialize Google Sign-In (v7+).
  // ! On Web, serverClientId must NOT be passed — the plugin asserts it is null.
  // * On mobile, clientId is the platform-specific OAuth client ID.
  // * serverClientId must be the WEB client ID so the backend can verify the
  // * idToken audience against the correct OAuth app registration.
  const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  const googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
  );

  final String? platformClientId;
  if (kIsWeb) {
    // * Web uses the web client ID; renderButton() handles the auth flow.
    platformClientId = googleWebClientId.isNotEmpty ? googleWebClientId : null;
  } else if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    platformClientId = googleIosClientId.isNotEmpty ? googleIosClientId : null;
  } else {
    platformClientId = googleAndroidClientId.isNotEmpty
        ? googleAndroidClientId
        : null;
  }

  if (platformClientId != null) {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(clientId: platformClientId);
    } else {
      await GoogleSignIn.instance.initialize(
        clientId: platformClientId,
        // * serverClientId is the web OAuth client — the backend validates
        // * the idToken's audience (aud) against this ID.
        serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
      );
    }
  } else {
    // ! Platform client ID is missing. Google OAuth flow will be disabled.
    debugPrint(
      '[GoogleSignIn] Platform client ID not configured — disabling OAuth.',
    );
  }

  if (kIsWeb) {
    const facebookAppId = String.fromEnvironment(
      'FACEBOOK_APP_ID',
      defaultValue: '1028619539827089',
    );
    await FacebookAuth.i.webAndDesktopInitialize(
      appId: facebookAppId,
      cookie: true,
      xfbml: true,
      version: 'v15.0',
    );
  }

  // * Persist settings + load backend URL / vote location BEFORE wiring clients.
  await HiveConfig.initialize();
  await ApiConfig.load();
  await LocationConfig.load();
  setupLocator();
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
      subscriptionProvider.refreshTier();
      syncManager.syncQueue();
    } else {
      pushTokenService.reset();
      subscriptionProvider.clear();
    }
  });
  if (authProvider.signedIn) {
    pushTokenService.registerIfNeeded();
    subscriptionProvider.refreshTier();
    syncManager.syncQueue();
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
        ChangeNotifierProvider.value(value: subscriptionProvider),
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
            builder: (context, child) {
              return OfflineHost(
                child: ProximityHost(
                  events: eventsProvider,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
