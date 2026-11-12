import 'dart:math';

import 'todo.dart';

/// Clé de jour « aaaa-mm-jj » utilisée pour l'historique.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// XP gagnés en terminant une tâche : selon la priorité, avec un bonus
/// si elle est terminée avant (ou le jour de) son échéance.
int xpForTodo(Todo todo, DateTime completedAt) {
  final base = switch (todo.priority) {
    Priority.low => 5,
    Priority.normal => 10,
    Priority.high => 20,
  };
  final onTime =
      todo.dueDate != null && !dateOnly(completedAt).isAfter(todo.dueDate!);
  return base + (onTime ? 5 : 0);
}

/// XP gagnés pour une session de focus : 1 XP toutes les 2 minutes.
int focusXp(int minutes) => minutes ~/ 2;

class LevelInfo {
  const LevelInfo(this.level, this.xpIntoLevel, this.xpForNext);

  final int level;
  final int xpIntoLevel;
  final int xpForNext;

  /// Il faut 100 × niveau XP pour passer au niveau suivant.
  factory LevelInfo.fromXp(int xp) {
    var level = 1;
    var remaining = xp;
    while (remaining >= 100 * level) {
      remaining -= 100 * level;
      level++;
    }
    return LevelInfo(level, remaining, 100 * level);
  }

  double get fraction => xpIntoLevel / xpForNext;

  String get title => switch (level) {
    < 3 => 'Débutant',
    < 5 => 'Apprenti',
    < 8 => 'Organisé',
    < 12 => 'Productif',
    < 20 => 'Maître du temps',
    _ => 'Légende',
  };
}

/// Progression du joueur : XP, séries de jours, focus, historique.
/// Elle survit à la suppression des tâches.
class Progress {
  Progress({
    this.xp = 0,
    this.completedCount = 0,
    this.focusMinutes = 0,
    this.bestStreak = 0,
    this.pomodoros = 0,
    Map<String, int>? daily,
  }) : daily = daily ?? {};

  int xp;
  int completedCount;
  int focusMinutes;
  int bestStreak;
  int pomodoros;

  /// Nombre de tâches terminées par jour.
  final Map<String, int> daily;

  LevelInfo get levelInfo => LevelInfo.fromXp(xp);

  /// Jours consécutifs avec au moins une tâche terminée. La série reste
  /// active tant qu'aujourd'hui n'est pas fini (on part d'hier si besoin).
  int currentStreak([DateTime? now]) {
    var day = dateOnly(now ?? DateTime.now());
    if ((daily[dayKey(day)] ?? 0) == 0) day = _previousDay(day);
    var streak = 0;
    while ((daily[dayKey(day)] ?? 0) > 0) {
      streak++;
      day = _previousDay(day);
    }
    return streak;
  }

  void recordCompletion(int gained, DateTime at) {
    xp += gained;
    completedCount++;
    daily.update(dayKey(at), (v) => v + 1, ifAbsent: () => 1);
    bestStreak = max(bestStreak, currentStreak(at));
  }

  /// Annule une complétion (tâche décochée) pour éviter de « farmer » l'XP.
  void undoCompletion(int lost, DateTime? at) {
    xp = max(0, xp - lost);
    completedCount = max(0, completedCount - 1);
    if (at == null) return;
    final key = dayKey(at);
    final v = (daily[key] ?? 0) - 1;
    if (v <= 0) {
      daily.remove(key);
    } else {
      daily[key] = v;
    }
  }

  void recordFocus(int minutes, {bool fullPomodoro = false}) {
    focusMinutes += minutes;
    xp += focusXp(minutes);
    if (fullPomodoro) pomodoros++;
  }

  /// Jour de la semaine (1 = lundi) où l'on termine le plus de tâches.
  /// `null` tant qu'il n'y a pas assez de données (au moins 5 tâches).
  ({int weekday, int count})? bestWeekday() {
    final totals = List<int>.filled(8, 0);
    for (final e in daily.entries) {
      final d = DateTime.tryParse(e.key);
      if (d != null) totals[d.weekday] += e.value;
    }
    final total = totals.fold(0, (a, b) => a + b);
    if (total < 5) return null;
    var best = 1;
    for (var w = 2; w <= 7; w++) {
      if (totals[w] > totals[best]) best = w;
    }
    return (weekday: best, count: totals[best]);
  }

  /// Complétions des [n] derniers jours, du plus ancien à aujourd'hui.
  List<(DateTime, int)> lastDays(int n, [DateTime? now]) {
    var day = dateOnly(now ?? DateTime.now());
    final result = <(DateTime, int)>[];
    for (var i = 0; i < n; i++) {
      result.add((day, daily[dayKey(day)] ?? 0));
      day = _previousDay(day);
    }
    return result.reversed.toList();
  }

  Set<String> get unlockedAchievements => {
    for (final a in achievements)
      if (a.isUnlocked(this)) a.id,
  };

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'completedCount': completedCount,
    'focusMinutes': focusMinutes,
    'bestStreak': bestStreak,
    'pomodoros': pomodoros,
    'daily': daily,
  };

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    xp: json['xp'] as int? ?? 0,
    completedCount: json['completedCount'] as int? ?? 0,
    focusMinutes: json['focusMinutes'] as int? ?? 0,
    bestStreak: json['bestStreak'] as int? ?? 0,
    pomodoros: json['pomodoros'] as int? ?? 0,
    daily: (json['daily'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as int),
    ),
  );
}

class Achievement {
  const Achievement(
    this.id,
    this.emoji,
    this.title,
    this.description,
    this.isUnlocked,
  );

  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(Progress) isUnlocked;
}

final achievements = <Achievement>[
  Achievement(
    'first',
    '🌱',
    'Premier pas',
    'Terminer une première tâche',
    (p) => p.completedCount >= 1,
  ),
  Achievement(
    'ten',
    '✅',
    'Sur la lancée',
    'Terminer 10 tâches',
    (p) => p.completedCount >= 10,
  ),
  Achievement(
    'fifty',
    '🏅',
    'Machine à cocher',
    'Terminer 50 tâches',
    (p) => p.completedCount >= 50,
  ),
  Achievement(
    'hundred',
    '💯',
    'Centurion',
    'Terminer 100 tâches',
    (p) => p.completedCount >= 100,
  ),
  Achievement(
    'streak3',
    '🔥',
    'En feu',
    'Série de 3 jours',
    (p) => p.bestStreak >= 3,
  ),
  Achievement(
    'streak7',
    '🌟',
    'Semaine parfaite',
    'Série de 7 jours',
    (p) => p.bestStreak >= 7,
  ),
  Achievement(
    'focus60',
    '🎧',
    'Concentré',
    "1 h de focus au total",
    (p) => p.focusMinutes >= 60,
  ),
  Achievement(
    'focus300',
    '🧘',
    'Moine zen',
    '5 h de focus au total',
    (p) => p.focusMinutes >= 300,
  ),
  Achievement(
    'tomato1',
    '🍅',
    'Première tomate',
    'Terminer un pomodoro',
    (p) => p.pomodoros >= 1,
  ),
  Achievement(
    'tomato10',
    '🧺',
    'Panier de tomates',
    'Terminer 10 pomodoros',
    (p) => p.pomodoros >= 10,
  ),
  Achievement(
    'level5',
    '👑',
    'Apprenti confirmé',
    'Atteindre le niveau 5',
    (p) => p.levelInfo.level >= 5,
  ),
];
