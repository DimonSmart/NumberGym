import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/logging/app_log_buffer.dart';
import 'features/training/data/card_progress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logBuffer = AppLogBuffer.instance;
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      logBuffer.add(message);
    }
    previousDebugPrint(message, wrapWidth: wrapWidth);
  };
  FlutterError.onError = (details) {
    logBuffer.add(details.toString());
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    logBuffer.add('Unhandled error: $error');
    logBuffer.add(stack.toString());
    return false;
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
}
