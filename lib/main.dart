import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'features/training/data/card_progress.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        AppLogger.instance.log(
          LogLevel.debug,
          'debugPrint',
          message,
          toConsole: false,
        );
      }
      previousDebugPrint(message, wrapWidth: wrapWidth);
    };

    FlutterError.onError = (details) {
      appLogE(
        'flutter',
        details.exceptionAsString(),
        error: details.exception,
        st: details.stack,
      );
      FlutterError.presentError(details);
    };

    final previousOnError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      appLogE('platform', 'Unhandled platform error', error: error, st: stack);
      return previousOnError?.call(error, stack) ?? false;
    };

    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );
    await Hive.initFlutter();
    Hive.registerAdapter(CardProgressAdapter());
    final settingsBox = await Hive.openBox<String>('settings');
    final progressBox = await Hive.openBox<CardProgress>('progress');

    runApp(
      NumbersTrainerApp(
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }, (error, stack) {
    appLogE('zone', 'Unhandled zoned error', error: error, st: stack);
  });
}
