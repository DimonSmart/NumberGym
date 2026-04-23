import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart';

import 'features/intro/ui/screens/intro_screen.dart';

const AppConfig numberGymConfig = AppConfig(
  appId: 'number_gym',
  title: 'Numbers Gym',
  homeTitle: 'Numbers Gym',
  repositoryUrl: 'https://github.com/DimonSmart/NumberGym',
  privacyPolicyUrl: 'https://dimonsmart.github.io/numbergym-privacy/',
  aboutTitle: 'About NumberGym',
  aboutBody:
      'NumberGym is a numbers-only language trainer built with a strict focus '
      'on practicing numbers, not general vocabulary, grammar, or themed lessons.\n\n'
      'Training is based on short cards and quick drills: you repeatedly practice '
      'the same number until it becomes automatic. Cards you answer correctly and '
      'consistently are removed from future sessions, so your practice stays '
      'focused on what still needs work.',
  settingsBoxName: 'settings',
  progressBoxName: 'progress_v2',
  heroAssetPath: 'assets/images/branding/wordmark.png',
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
      title: numberGymConfig.title,
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
      home: IntroScreen(
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }
}
