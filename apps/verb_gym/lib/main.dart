import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(CardProgressAdapter());

  final settingsBox = await Hive.openBox<String>(verbGymConfig.settingsBoxName);
  final progressBox = await Hive.openBox<CardProgress>(
    verbGymConfig.progressBoxName,
  );
  final runtimeCatalog = await VerbAuthoringAssetLoader().loadRuntimeCatalog();
  final appDefinition = buildVerbGymAppDefinition(
    config: verbGymConfig,
    runtimeCatalog: runtimeCatalog,
  );

  runApp(
    VerbGymApp(
      appDefinition: appDefinition,
      settingsBox: settingsBox,
      progressBox: progressBox,
    ),
  );
}
