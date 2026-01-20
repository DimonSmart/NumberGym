import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'features/training/data/card_progress.dart';
import 'features/training/ui/screens/training_screen.dart';

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
      seedColor: const Color(0xFF0B7A77),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Numbers Trainer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        scaffoldBackgroundColor: colorScheme.surface,
      ),
      home: TrainingScreen(
        settingsBox: settingsBox,
        progressBox: progressBox,
      ),
    );
  }
}
