enum Priority {
  low('Basse'),
  normal('Normale'),
  high('Haute');

  const Priority(this.label);
  final String label;

  static Priority fromName(String? name) => Priority.values.firstWhere(
    (p) => p.name == name,
    orElse: () => Priority.normal,
  );
}

class Todo {
  final String id;
  String title;
  String notes;
  bool done;
  Priority priority;

  /// Date d'échéance (jour uniquement, sans heure).
  DateTime? dueDate;
  final DateTime createdAt;

  /// Quand la tâche a été cochée, et combien d'XP elle a rapporté
  /// (pour pouvoir les retirer si elle est décochée).
  DateTime? completedAt;
  int xpAwarded;

  /// Nombre de pomodoros complets passés sur cette tâche.
  int pomodoros;

  Todo({
    required this.id,
    required this.title,
    this.notes = '',
    this.done = false,
    this.priority = Priority.normal,
    DateTime? dueDate,
    DateTime? createdAt,
    this.completedAt,
    this.xpAwarded = 0,
    this.pomodoros = 0,
  }) : dueDate = dueDate == null ? null : dateOnly(dueDate),
       createdAt = createdAt ?? DateTime.now();

  /// Vrai si la tâche n'est pas terminée et que son échéance est passée.
  bool isOverdue([DateTime? now]) =>
      !done &&
      dueDate != null &&
      dueDate!.isBefore(dateOnly(now ?? DateTime.now()));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'done': done,
    'priority': priority.name,
    'dueDate': dueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'xpAwarded': xpAwarded,
    'pomodoros': pomodoros,
  };

  /// Compatible avec les données sauvegardées par l'ancienne version
  /// (sans notes, priorité ni échéance).
  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    notes: json['notes'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    priority: Priority.fromName(json['priority'] as String?),
    dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    xpAwarded: json['xpAwarded'] as int? ?? 0,
    pomodoros: json['pomodoros'] as int? ?? 0,
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
