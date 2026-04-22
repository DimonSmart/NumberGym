import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trainer_core/trainer_core.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(CardProgressAdapter());

  final settingsBox = await Hive.openBox<String>(verbGymConfig.settingsBoxName);
  final progressBox = await Hive.openBox<CardProgress>(
    verbGymConfig.progressBoxName,
  );

  runApp(VerbGymApp(settingsBox: settingsBox, progressBox: progressBox));
}
