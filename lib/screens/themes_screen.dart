import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../theme/app_themes.dart';
import '../widgets/progress_card.dart';

/// Choix du thème de couleur (débloqués par niveau) et du mode clair/sombre.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    final unlockedCount = appThemes.where((t) => t.isUnlocked(level)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Thèmes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Apparence', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('Système'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Clair'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Sombre'),
              ),
            ],
            selected: {settings.mode},
            onSelectionChanged: (s) => settings.setMode(s.first),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Couleurs', style: theme.textTheme.titleMedium),
              ),
              Text(
                '$unlockedCount / ${appThemes.length} débloqués',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Monte de niveau pour débloquer de nouvelles couleurs.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              for (final t in appThemes)
                _ThemeCard(
                  appTheme: t,
                  unlocked: t.isUnlocked(level),
                  selected: settings.theme.id == t.id,
                  onTap: () => settings.setTheme(t),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.appTheme,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final AppTheme appTheme;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    // Aperçu des vraies couleurs du thème, dans la luminosité actuelle.
    final preview = appTheme.data(current.brightness).colorScheme;

    return Card(
      key: Key('theme-${appTheme.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? current.colorScheme.primary : Colors.transparent,
          width: 3,
        ),
      ),
      child: InkWell(
        onTap: unlocked ? onTap : null,
        child: Opacity(
          opacity: unlocked ? 1 : 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(gradient: heroGradient(preview)),
                  alignment: Alignment.center,
                  child: unlocked
                      ? (selected
                            ? Icon(
                                Icons.check_circle,
                                color: heroForeground(preview),
                                size: 32,
                              )
                            : Text(
                                appTheme.emoji,
                                style: const TextStyle(fontSize: 32),
                              ))
                      : Icon(
                          Icons.lock,
                          color: heroForeground(preview),
                          size: 28,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appTheme.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      unlocked
                          ? (selected ? 'Actif' : 'Débloqué')
                          : 'Niveau ${appTheme.requiredLevel} requis',
                      style: current.textTheme.labelSmall?.copyWith(
                        color: current.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
