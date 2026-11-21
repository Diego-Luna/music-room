import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, defaultTargetPlatform;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/core/repositories/offline_friends_repository.dart';
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
  // * Silence client-side debugPrint logs in release builds (Web/mobile prod)
  //   while keeping full logs in debug/profile and backend V.6 logs intact.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  setUrlStrategy(HashUrlStrategy());
  WidgetsFlutterBinding.ensureInitialized();

  // * Initialize Google Sign-In (v7+).
  // ! initialize() MUST always be called — even when --dart-define values are
  //   omitted — so Web reads <meta name="google-signin-client_id">, iOS reads
  //   GIDClientID/GIDServerClientID from Info.plist, and Android initializes
  //   via google-services / SHA-1 + serverClientId.
  // ! On Web, serverClientId must NOT be passed — the plugin asserts it is null.
  const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  const googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
  );

  try {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await GoogleSignIn.instance.initialize(
        clientId: googleIosClientId.isNotEmpty ? googleIosClientId : null,
        serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
      );
    } else {
      await GoogleSignIn.instance.initialize(
        clientId: googleAndroidClientId.isNotEmpty
            ? googleAndroidClientId
            : null,
        serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
      );
    }
  } catch (e) {
    debugPrint('[GoogleSignIn] Initialization failed: $e');
  }

  if (kIsWeb) {
    const facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');
    if (facebookAppId.isNotEmpty) {
      await FacebookAuth.i.webAndDesktopInitialize(
        appId: facebookAppId,
        cookie: true,
        xfbml: true,
        version: 'v15.0',
      );
    }
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
  bool wasSignedIn = authProvider.signedIn;
  authProvider.addListener(() {
    final isSignedIn = authProvider.signedIn;
    if (isSignedIn && !wasSignedIn) {
      wasSignedIn = true;
      pushTokenService.registerIfNeeded();
      subscriptionProvider.refreshTier();
      syncManager.syncQueue();
    } else if (!isSignedIn && wasSignedIn) {
      wasSignedIn = false;
      pushTokenService.reset();
      subscriptionProvider.clear();
      // ! V.6: wipe all user-scoped local caches and providers on logout so
      //   switching accounts on the same device never exposes prior user data.
      eventsProvider.clear();
      playlistsProvider.clear();
      roomsProvider.clear();
      friendsProvider.clear();
      notificationsProvider.clear();
      playerProvider.clear();
      unawaited(offlineCache.clear());
      final friendsRepo = friendsRepository;
      if (friendsRepo is OfflineFriendsRepository) {
        unawaited(friendsRepo.clear());
      }
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
