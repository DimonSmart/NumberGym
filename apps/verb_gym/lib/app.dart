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
  privacyPolicyUrl:
      'https://github.com/DimonSmart/NumberGym/blob/main/README.md',
  aboutTitle: 'About Verb Gym',
  aboutBody:
      'Verb Gym drills present, past, and future forms with speech, listening, and fast recognition loops.',
  settingsBoxName: 'verb_gym_settings',
  progressBoxName: 'verb_gym_progress',
  heroAssetPath: 'assets/images/branding/wordmark.png',
  mascotAssetPath: 'assets/images/app_icon_transparent.png',
  languageSettingsMode: LanguageSettingsMode.baseAndLearningLanguage,
  defaultBaseLanguage: LearningLanguage.english,
  defaultLearningLanguage: LearningLanguage.spanish,
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.deepBlue,
      brightness: Brightness.light,
      primary: AppPalette.deepBlue,
      onPrimary: Colors.white,
      secondary: AppPalette.brandGold,
      tertiary: AppPalette.warmOrange,
      surface: AppPalette.iceBackground,
      onSurface: Colors.black87,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: verbGymConfig.title,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        fontFamily: 'SpaceGrotesk',
        scaffoldBackgroundColor: AppPalette.iceBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: AppPalette.iceBackground,
          foregroundColor: AppPalette.deepBlue,
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
