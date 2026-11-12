import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../theme/app_themes.dart';
import '../theme/app_theme_data.dart';
import '../widgets/progress_card.dart';
import 'themes_screen.dart';

const _weekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.progress});

  final Progress progress;

  void _openThemes(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ThemesScreen(level: progress.levelInfo.level),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = progress.levelInfo;
    final unlocked = progress.unlockedAchievements;
    final heroFg = heroForeground(scheme);
    final insight = _insight(progress);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma progression'),
        actions: [
          IconButton(
            tooltip: 'Thèmes',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _openThemes(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête : niveau
          Container(
            decoration: BoxDecoration(
              gradient: heroGradient(scheme),
              borderRadius: BorderRadius.circular(Radii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LevelBadge(level: info.level, size: 80, inverted: true),
                  const SizedBox(height: 12),
                  Text(
                    info.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: heroFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Niveau ${info.level} · ${progress.xp} XP au total',
                    style: theme.textTheme.bodyMedium?.copyWith(color: heroFg),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: info.fraction,
                      color: heroFg,
                      minHeight: 10,
                      backgroundColor: heroFg.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Encore ${info.xpForNext - info.xpIntoLevel} XP avant le niveau ${info.level + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(color: heroFg),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Thèmes de couleur'),
              subtitle: Text(
                '${appThemes.where((t) => t.isUnlocked(info.level)).length} / ${appThemes.length} débloqués',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openThemes(context),
            ),
          ),
          const SizedBox(height: 12),

          // Chiffres clés
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              _StatTile(
                '🔥',
                '${progress.currentStreak()} j',
                'Série actuelle',
              ),
              _StatTile('🏆', '${progress.bestStreak} j', 'Meilleure série'),
              _StatTile('✅', '${progress.completedCount}', 'Tâches terminées'),
              _StatTile('🎧', formatMinutes(progress.focusMinutes), 'Focus'),
              _StatTile('🍅', '${progress.pomodoros}', 'Pomodoros'),
              _StatTile('⚡', '${progress.xp}', 'XP au total'),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.secondaryContainer,
              child: ListTile(
                leading: const Text('🧠', style: TextStyle(fontSize: 26)),
                title: Text(
                  insight,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          Text('7 derniers jours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _WeekChart(days: progress.lastDays(7)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Text('Succès', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${unlocked.length} / ${achievements.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final a in achievements)
            _AchievementTile(achievement: a, unlocked: unlocked.contains(a.id)),
        ],
      ),
    );
  }
}

const _weekdayNames = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche', //
];

/// Un constat personnalisé tiré de l'historique.
String? _insight(Progress p) {
  final best = p.bestWeekday();
  if (best != null) {
    return 'Ton jour le plus productif : le ${_weekdayNames[best.weekday - 1]} '
        '(${best.count} tâches). Garde les tâches difficiles pour ce jour-là !';
  }
  if (p.pomodoros >= 3 && p.completedCount > 0) {
    return 'Tu as déjà fait ${p.pomodoros} pomodoros : continue, la '
        'concentration est un muscle.';
  }
  return null;
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.emoji, this.value, this.label);

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Histogramme simple : une barre par jour, aujourd'hui mis en avant.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<(DateTime, int)> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCount = days
        .fold<int>(0, (m, d) => d.$2 > m ? d.$2 : m)
        .clamp(1, 1 << 30);
    const chartHeight = 120.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, (day, count)) in days.indexed)
              Expanded(
                child: Tooltip(
                  message:
                      '${day.day}/${day.month} : $count tâche${count > 1 ? 's' : ''}',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Column(
                    children: [
                      Text(
                        count > 0 ? '$count' : '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: chartHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 18,
                            height: count == 0
                                ? 2
                                : chartHeight * count / maxCount,
                            decoration: BoxDecoration(
                              color: count == 0
                                  ? scheme.outlineVariant
                                  : i == days.length - 1
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i == days.length - 1
                            ? 'Auj.'
                            : _weekdayLetters[day.weekday - 1],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: i == days.length - 1
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: unlocked ? scheme.secondaryContainer : null,
      child: ListTile(
        leading: Opacity(
          opacity: unlocked ? 1 : 0.35,
          child: Text(achievement.emoji, style: const TextStyle(fontSize: 28)),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: unlocked ? null : scheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(achievement.description),
        trailing: unlocked
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.lock_outline, color: scheme.outline),
      ),
    );
  }
}
