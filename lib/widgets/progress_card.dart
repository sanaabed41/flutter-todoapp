import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../theme/app_theme_data.dart';

/// Dégradé principal de l'app (couleur primaire → tertiaire du thème).
/// La 2e couleur est la primaire décalée de 35° sur le cercle chromatique :
/// un dégradé harmonieux quel que soit le thème choisi.
/// Couleur de base du « héros » : la primaire en mode clair, sa version
/// profonde en mode sombre (plus élégant qu'un pastel lumineux).
Color heroBase(ColorScheme s) =>
    s.brightness == Brightness.dark ? s.primaryContainer : s.primary;

/// Couleur du texte posé sur le dégradé.
Color heroForeground(ColorScheme s) =>
    s.brightness == Brightness.dark ? s.onPrimaryContainer : s.onPrimary;

LinearGradient heroGradient(ColorScheme scheme) {
  final hsl = HSLColor.fromColor(heroBase(scheme));
  final end = hsl
      .withHue((hsl.hue + 35) % 360)
      .withLightness((hsl.lightness + 0.04).clamp(0.0, 1.0))
      .toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroBase(scheme), end],
  );
}

/// Carte « héros » en haut de la liste : niveau, barre d'XP et série.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.progress, required this.onTap});

  final Progress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = progress.levelInfo;
    final streak = progress.currentStreak();
    final fg = heroForeground(scheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        key: const Key('progress-card'),
        borderRadius: BorderRadius.circular(Radii.lg),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: heroGradient(scheme)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  LevelBadge(level: info.level, size: 52, inverted: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niveau ${info.level} · ${info.title}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: info.fraction,
                          minHeight: 8,
                          color: fg,
                          backgroundColor: fg.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${info.xpIntoLevel} / ${info.xpForNext} XP',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: fg.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Série de jours',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Column(
                        children: [
                          Text(
                            streak > 0 ? '🔥' : '💤',
                            style: const TextStyle(fontSize: 20),
                          ),
                          Text(
                            '$streak j',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
    this.size = 48,
    this.inverted = false,
  });

  final int level;
  final double size;

  /// Version claire, pour être posée sur le dégradé.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: inverted ? heroForeground(scheme) : null,
        gradient: inverted ? null : heroGradient(scheme),
        border: inverted
            ? Border.all(
                color: heroForeground(scheme).withValues(alpha: 0.4),
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
      ),
      child: Text(
        '$level',
        style: TextStyle(
          color: inverted ? heroBase(scheme) : heroForeground(scheme),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          height: 1.1,
        ),
      ),
    );
  }
}
