import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_room_app/routes/route_names.dart';
import 'package:music_room_app/routes/app_router.dart';
import 'package:music_room_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase: $e');
    }
  }

  setupLocator();
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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Music Room',
        initialRoute: routeSplash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        theme: AppTheme.lightTheme,
      ),
    );
  }
}
