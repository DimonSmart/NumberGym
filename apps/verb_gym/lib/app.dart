import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

import 'home_screen.dart';

const AppConfig verbGymConfig = AppConfig(
  appId: 'verb_gym',
  title: 'Verb Gym',
  homeTitle: 'Verb Gym',
  repositoryUrl: 'https://github.com/DimonSmart/NumberGym',
  privacyPolicyUrl: 'https://github.com/DimonSmart/NumberGym/blob/main/README.md',
  aboutTitle: 'About Verb Gym',
  aboutBody:
      'Verb Gym drills present, past, and future forms with speech, listening, and fast recognition loops.',
  settingsBoxName: 'verb_gym_settings',
  progressBoxName: 'verb_gym_progress',
  heroAssetPath: 'assets/images/intro.png',
  mascotAssetPath: 'assets/images/app_icon.png',
);

final TrainingAppDefinition verbGymDefinition = buildVerbGymAppDefinition(
  config: verbGymConfig,
);

class VerbGymApp extends StatelessWidget {
  const VerbGymApp({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0E5A47);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: const Color(0xFF0E5A47),
      secondary: const Color(0xFFF28F3B),
      tertiary: const Color(0xFF2A2D34),
      surface: const Color(0xFFFFFAF2),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: verbGymConfig.title,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        fontFamily: 'SpaceGrotesk',
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      home: VerbGymHomeScreen(
        config: verbGymConfig,
        appDefinition: verbGymDefinition,
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }
}
