import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'core/theme/app_palette.dart';
import 'features/training/data/card_progress.dart';
import 'features/intro/ui/screens/intro_screen.dart';

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
      home: IntroScreen(
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }
}
