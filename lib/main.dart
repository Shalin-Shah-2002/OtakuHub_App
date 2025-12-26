import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'controllers/anime_controller.dart';
import 'services/storage_service.dart';
import 'services/download_service.dart';
import 'views/main_navigation.dart';
import 'views/base_url_screen.dart';
import 'utils/logger_service.dart';
import 'utils/one_piece_theme.dart';

void main() async {
  // Run the app in a guarded zone to catch all errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Initialize media_kit for video playback
      MediaKit.ensureInitialized();

      setupGlobalErrorHandling();

      // Configure logger
      logger.configure(
        minLevel: LogLevel.verbose,
        enableConsoleOutput: true,
        maxLogHistory: 2000,
      );

      logger.i('APP', '🚀 App starting...');
      logger.i('APP', 'Flutter Anime App v1.0.0');

      // Initialize services
      await _initServices();

      runApp(const MyApp());
    },
    (error, stackTrace) {
      // Catch any errors that escape the Flutter framework
      logger.f(
        'ZONE',
        'Uncaught error in zone',
        error: error,                 
        stackTrace: stackTrace,
      );
    },
  );
}

/// Initialize all services before app starts
Future<void> _initServices() async {
  logger.i('APP', 'Initializing services...');

  // Initialize storage service first
  await Get.putAsync(() => StorageService().init());

  // Initialize download service
  await Get.putAsync(() => DownloadService().init());

  logger.i('APP', 'All services initialized');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    logger.d('APP', 'Building MyApp widget');

    // Initialize controller
    Get.put(AnimeController());

    logger.i('APP', 'AnimeController registered with GetX');

    // Check if this is first launch
    final storageService = Get.find<StorageService>();
    final isFirstLaunch = storageService.isFirstLaunch();

    logger.i('APP', 'First launch: $isFirstLaunch');

    return GetMaterialApp(
      title: 'OtakuHub',
      debugShowCheckedModeBanner: false,
      theme: OnePieceTheme.lightTheme,
      darkTheme: OnePieceTheme.darkTheme,
      themeMode:
          ThemeMode.dark, // Default to dark mode for that Grand Line feel!
      // Add navigation observer for logging
      navigatorObservers: [LoggingNavigatorObserver()],
      initialRoute: isFirstLaunch ? '/setup' : '/home',
      getPages: [
        GetPage(
          name: '/setup',
          page: () => const BaseUrlScreen(isFirstLaunch: true),
        ),
        GetPage(name: '/home', page: () => const MainNavigation()),
        GetPage(
          name: '/base-url',
          page: () => const BaseUrlScreen(isFirstLaunch: false),
        ),
      ],
    );
  }
}

/// Navigator observer for logging navigation events
class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    logger.logNavigation(
      previousRoute?.settings.name ?? 'null',
      route.settings.name ?? route.runtimeType.toString(),
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    logger.logNavigation(
      route.settings.name ?? route.runtimeType.toString(),
      previousRoute?.settings.name ?? 'null',
      params: {'action': 'pop'},
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    logger.logNavigation(
      oldRoute?.settings.name ?? 'null',
      newRoute?.settings.name ?? 'null',
      params: {'action': 'replace'},
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
