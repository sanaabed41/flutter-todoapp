/// Réglages du Pomodoro (en minutes).
class PomodoroConfig {
  const PomodoroConfig({
    this.focus = 25,
    this.shortBreak = 5,
    this.longBreak = 15,
    this.longEvery = 4,
    this.autoStart = false,
  });

  final int focus;
  final int shortBreak;
  final int longBreak;

  /// Une pause longue toutes les N sessions de focus.
  final int longEvery;

  /// Enchaîner automatiquement focus → pause → focus.
  final bool autoStart;

  PomodoroConfig copyWith({
    int? focus,
    int? shortBreak,
    int? longBreak,
    int? longEvery,
    bool? autoStart,
  }) => PomodoroConfig(
    focus: focus ?? this.focus,
    shortBreak: shortBreak ?? this.shortBreak,
    longBreak: longBreak ?? this.longBreak,
    longEvery: longEvery ?? this.longEvery,
    autoStart: autoStart ?? this.autoStart,
  );

  Map<String, dynamic> toJson() => {
    'focus': focus,
    'shortBreak': shortBreak,
    'longBreak': longBreak,
    'longEvery': longEvery,
    'autoStart': autoStart,
  };

  factory PomodoroConfig.fromJson(Map<String, dynamic> json) => PomodoroConfig(
    focus: json['focus'] as int? ?? 25,
    shortBreak: json['shortBreak'] as int? ?? 5,
    longBreak: json['longBreak'] as int? ?? 15,
    longEvery: json['longEvery'] as int? ?? 4,
    autoStart: json['autoStart'] as bool? ?? false,
  );
}
