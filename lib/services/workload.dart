import '../models/progress.dart';
import '../models/todo.dart';

/// Rythme par défaut tant qu'on n'a pas assez d'historique.
const defaultCapacity = 3;

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Nombre de tâches que l'utilisateur termine habituellement par jour,
/// calculé sur les 14 derniers jours où il a été actif.
int dailyCapacity(Progress progress, {DateTime? now}) {
  final days = progress.lastDays(14, now).where((d) => d.$2 > 0).toList();
  final total = days.fold(0, (sum, d) => sum + d.$2);
  if (total < 5) return defaultCapacity;
  return (total / days.length).round().clamp(2, 12);
}

/// Charge d'une journée : les tâches non terminées prévues ce jour-là.
class DayLoad {
  DayLoad(this.day, this.tasks, this.capacity);

  final DateTime day;
  final List<Todo> tasks;
  final int capacity;

  int get count => tasks.length;
  bool get overloaded => count > capacity;
  int get excess => count - capacity;
}

/// Importance décroissante : priorité, puis tâche la plus ancienne.
int compareImportance(Todo a, Todo b) {
  final byPriority = b.priority.index.compareTo(a.priority.index);
  if (byPriority != 0) return byPriority;
  return a.createdAt.compareTo(b.createdAt);
}

/// Charge des [days] prochains jours. Les tâches en retard comptent dans
/// la charge d'aujourd'hui, puisque c'est aujourd'hui qu'il faut les faire.
List<DayLoad> upcomingLoad(
  List<Todo> todos,
  int capacity, {
  DateTime? now,
  int days = 14,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final buckets = List.generate(days, (_) => <Todo>[]);
  for (final t in todos) {
    if (t.done || t.dueDate == null) continue;
    final offset = daysBetween(today, t.dueDate!);
    if (offset < days) buckets[offset < 0 ? 0 : offset].add(t);
  }
  return [
    for (var i = 0; i < days; i++)
      DayLoad(addDays(today, i), buckets[i]..sort(compareImportance), capacity),
  ];
}

class Move {
  const Move(this.todo, this.from, this.to);

  final Todo todo;
  final DateTime? from;
  final DateTime to;
}

/// Propose de déplacer les tâches les moins importantes des jours
/// surchargés vers les prochains jours qui ont de la place, sans jamais
/// surcharger un autre jour. Les tâches de priorité haute ne bougent pas.
List<Move> planRebalance(
  List<Todo> todos,
  int capacity, {
  DateTime? now,
  int horizon = 14,
}) {
  final loads = upcomingLoad(todos, capacity, now: now, days: horizon);
  final counts = [for (final l in loads) l.count];
  final moves = <Move>[];

  for (var d = 0; d < horizon; d++) {
    if (counts[d] <= capacity) continue;
    // Les moins importantes d'abord (fin de la liste triée).
    final movable = loads[d].tasks
        .where((t) => t.priority != Priority.high)
        .toList()
        .reversed;
    for (final t in movable) {
      if (counts[d] <= capacity) break;
      final target = _nextFreeDay(counts, capacity, d + 1);
      if (target == null) break;
      moves.add(Move(t, t.dueDate, loads[target].day));
      counts[d]--;
      counts[target]++;
    }
  }
  return moves;
}

int? _nextFreeDay(List<int> counts, int capacity, int from) {
  for (var i = from; i < counts.length; i++) {
    if (counts[i] < capacity) return i;
  }
  return null;
}
