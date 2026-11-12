import '../models/todo.dart';

class Suggestion {
  const Suggestion(this.todo, this.reason, this.score);

  final Todo todo;

  /// Explication lisible : pourquoi cette tâche maintenant.
  final String reason;
  final int score;
}

/// Choisit la tâche la plus pertinente à faire maintenant, en combinant
/// l'urgence (échéance), l'importance (priorité) et l'ancienneté.
/// Les tâches de [exclude] (ids) sont ignorées.
Suggestion? suggestNext(
  List<Todo> todos, {
  DateTime? now,
  Set<String> exclude = const {},
}) {
  final today = dateOnly(now ?? DateTime.now());
  Suggestion? best;

  for (final t in todos) {
    if (t.done || exclude.contains(t.id)) continue;
    final s = _score(t, today, now ?? DateTime.now());
    if (best == null || s.score > best.score) best = s;
  }
  return best;
}

Suggestion _score(Todo t, DateTime today, DateTime now) {
  var score = 0;
  final reasons = <(int, String)>[];

  final due = t.dueDate;
  if (due != null) {
    final days = DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final (pts, why) = switch (days) {
      < 0 => (
        100 + 10 * (-days).clamp(0, 10),
        'En retard de ${-days} jour${days < -1 ? 's' : ''}',
      ),
      0 => (80, "À faire aujourd'hui"),
      1 => (55, 'Pour demain'),
      <= 3 => (30, 'Échéance dans $days jours'),
      <= 7 => (15, 'Échéance cette semaine'),
      _ => (0, ''),
    };
    score += pts;
    if (pts > 0) reasons.add((pts, why));
  }

  final pPts = switch (t.priority) {
    Priority.high => 40,
    Priority.normal => 15,
    Priority.low => 0,
  };
  score += pPts;
  if (t.priority == Priority.high) reasons.add((pPts, 'Priorité haute'));

  // Une tâche qui traîne depuis longtemps remonte doucement.
  final age = today.difference(dateOnly(t.createdAt)).inDays.clamp(0, 14);
  score += age;
  if (age >= 5) reasons.add((age, 'En attente depuis $age jours'));

  // Déjà commencée en pomodoro : on aide à la finir.
  if (t.pomodoros > 0) {
    score += 10;
    reasons.add((10, 'Déjà ${t.pomodoros} 🍅 dessus, termine-la'));
  }

  reasons.sort((a, b) => b.$1.compareTo(a.$1));
  final reason = reasons.isEmpty
      ? (now.hour >= 20
            ? 'Une petite tâche pour finir la journée'
            : 'Prochaine étape logique')
      : reasons.take(2).map((r) => r.$2).join(' · ');
  return Suggestion(t, reason, score);
}
