import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tube_sync/app/app_theme.dart';
import 'package:tube_sync/app/home/home_screen.dart';
import 'package:tube_sync/model/media.dart';
import 'package:tube_sync/model/playlist.dart';
import 'package:tube_sync/model/preferences.dart';
import 'package:tube_sync/services/downloader_service.dart';
import 'package:tube_sync/services/media_service.dart';
import 'package:window_manager/window_manager.dart';

final rootNavigator = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppTheme.isDesktop) {
    await WindowManager.instance.ensureInitialized();
    WindowManager.instance.setIcon("assets/tubesync.png");
    WindowManager.instance.setMinimumSize(const Size(480, 360));
  }

  // DB Initialization
  final isarDB = Isar.open(
    schemas: [PreferencesSchema, PlaylistSchema, MediaSchema],
    directory: (await getApplicationSupportDirectory()).path,
  );

  AppTheme.dynamicColors.value = isarDB.preferences.getValue<bool>(
    Preference.materialYou,
  );

  await DownloaderService.init();
  await MediaService.init();

  MaterialApp app({
    required ThemeData light,
    required ThemeData dark,
    required Widget home,
  }) {
    return MaterialApp(
      navigatorKey: rootNavigator,
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      scrollBehavior: AppTheme.scrollBehavior,
      home: home,
    );
  }

  runApp(
    ValueListenableBuilder(
      valueListenable: AppTheme.dynamicColors,
      builder: (_, dynamicColor, home) {
        if (dynamicColor == true) {
          return DynamicColorBuilder(
            builder: (light, dark) => app(
              light: AppTheme(colorScheme: light).light,
              dark: AppTheme(colorScheme: dark).dark,
              home: home!,
            ),
          );
        }

        return app(light: AppTheme().light, dark: AppTheme().dark, home: home!);
      },
      child: DragToResizeArea(
        child: Provider<Isar>(
          create: (context) => isarDB,
          child: const HomeScreen(),
        ),
      ),
    ),
  );
  // Ensure permissions
  Future.wait([
    Permission.notification.isDenied,
    Permission.ignoreBatteryOptimizations.isDenied
  ]).then((result) async {
    if (result[0]) await Permission.notification.request();
    if (result[1]) await Permission.ignoreBatteryOptimizations.request();
  }).catchError((_) {});
}
