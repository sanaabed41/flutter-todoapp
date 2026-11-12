import 'package:flutter/material.dart';

import 'app_theme_data.dart';

/// Un thème de couleur débloqué en atteignant un certain niveau.
class AppTheme {
  const AppTheme(this.id, this.name, this.emoji, this.seed, this.requiredLevel);

  final String id;
  final String name;
  final String emoji;
  final Color seed;
  final int requiredLevel;

  bool isUnlocked(int level) => level >= requiredLevel;

  ThemeData data(Brightness brightness) => buildAppTheme(seed, brightness);
}

const appThemes = <AppTheme>[
  AppTheme('indigo', 'Indigo', '💙', Colors.indigo, 1),
  AppTheme('emerald', 'Émeraude', '🌿', Color(0xFF2E7D32), 2),
  AppTheme('coral', 'Corail', '🪸', Color(0xFFFF7043), 3),
  AppTheme('lavender', 'Lavande', '💜', Color(0xFF9575CD), 4),
  AppTheme('ocean', 'Océan', '🌊', Color(0xFF0277BD), 6),
  AppTheme('sakura', 'Sakura', '🌸', Color(0xFFEC407A), 8),
  AppTheme('gold', 'Or', '👑', Color(0xFFFFB300), 10),
  AppTheme('midnight', 'Minuit', '🌌', Color(0xFF311B92), 15),
];

AppTheme themeById(String? id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

/// Thèmes débloqués en passant de [from] à [to] (exclu / inclus).
List<AppTheme> themesUnlockedBetween(int from, int to) => appThemes
    .where((t) => t.requiredLevel > from && t.requiredLevel <= to)
    .toList();
