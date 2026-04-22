import 'dart:ui';

abstract class AppPalette {
  /// Primary Blue (Character Blue)
  /// Use for primary accents, icons, highlights, friendly UI emphasis.
  static const Color primaryBlue = Color(0xFF72BFE6);

  /// Deep Blue (Support Blue)
  /// Use for pressed states, stronger contrast accents, outlines/shadows.
  static const Color deepBlue = Color(0xFF26679D);

  /// Brand Gold (Logo Gold)
  /// Use for main brand accent, key callouts, badges, rewards.
  static const Color brandGold = Color(0xFFFEB60B);

  /// Warm Orange (Secondary Accent)
  /// Use for secondary highlights, energy cues, small emphasis details.
  static const Color warmOrange = Color(0xFFE37E21);

  /// Ice Background (App Background)
  /// Use as the main background / canvas color.
  static const Color iceBackground = Color(0xFFF3F9FE);
}
