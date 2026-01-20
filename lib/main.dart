import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/training/data/card_progress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
