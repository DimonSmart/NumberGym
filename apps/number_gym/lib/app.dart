import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart' hide AppPalette;

import 'core/theme/app_palette.dart';
import 'home_screen.dart';

const AppConfig numberGymConfig = AppConfig(
  appId: 'number_gym',
  title: 'Number Gym',
  homeTitle: 'Number Gym',
  repositoryUrl: 'https://github.com/DimonSmart/NumberGym',
  privacyPolicyUrl: 'https://dimonsmart.github.io/numbergym-privacy/',
  aboutTitle: 'About Number Gym',
  aboutBody:
      'Number Gym drills numbers, time, and phone formats with speech, listening, and fast recognition loops.',
  settingsBoxName: 'settings',
  progressBoxName: 'progress_v2',
  heroAssetPath: 'assets/images/numbers_gym_name.png',
  mascotAssetPath: 'assets/images/app_icon_transparent.png',
);

final TrainingAppDefinition numberGymDefinition = buildNumberGymAppDefinition(
  config: numberGymConfig,
);

class NumbersTrainerApp extends StatelessWidget {
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  const NumbersTrainerApp({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  @override
  Widget build(BuildContext context) {
    // Creating a custom color scheme based on the brand palette
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
      title: 'Numbers Gym',
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
      home: NumberGymHomeScreen(
        config: numberGymConfig,
        appDefinition: numberGymDefinition,
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }
}
