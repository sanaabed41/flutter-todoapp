import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pomodoro_config.dart';
import '../models/progress.dart';
import '../models/todo.dart';
import '../services/settings_controller.dart';

enum PomodoroPhase {
  focus('Focus', '🍅'),
  shortBreak('Pause courte', '☕'),
  longBreak('Pause longue', '🌴');

  const PomodoroPhase(this.label, this.emoji);
  final String label;
  final String emoji;

  bool get isBreak => this != PomodoroPhase.focus;
}

/// Appelé à chaque fois que des minutes de focus sont acquises :
/// pomodoro complet, ou session interrompue (minutes partielles).
typedef FocusCallback = void Function(int minutes, {required bool full});

/// Minuteur Pomodoro : focus → pause courte → … → pause longue.
/// Peut être lié à une tâche ([todo]) ou utilisé librement.
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({
    super.key,
    this.todo,
    this.onFocus,
    this.clock = DateTime.now,
  });

  final Todo? todo;
  final FocusCallback? onFocus;

  /// Horloge injectable (pour les tests).
  final DateTime Function() clock;

  /// Ouvre l'écran. Renvoie `true` si l'utilisateur a marqué la tâche
  /// comme terminée.
  static Future<bool?> open(
    BuildContext context, {
    Todo? todo,
    FocusCallback? onFocus,
  }) => Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PomodoroScreen(todo: todo, onFocus: onFocus),
    ),
  );

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroPhase _phase = PomodoroPhase.focus;
  int _completed = 0;
  Duration? _remaining;
  DateTime? _endAt;
  Timer? _timer;

  PomodoroConfig get _config =>
      SettingsScope.maybeOf(context)?.pomodoro ?? const PomodoroConfig();

  Duration _durationOf(PomodoroPhase phase) => Duration(
    minutes: switch (phase) {
      PomodoroPhase.focus => _config.focus,
      PomodoroPhase.shortBreak => _config.shortBreak,
      PomodoroPhase.longBreak => _config.longBreak,
    },
  );

  Duration get _total => _durationOf(_phase);
  Duration get _left => _remaining ?? _total;
  bool get _running => _timer != null;
  bool get _started => _running || _left < _total;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _endAt = widget.clock().add(_left);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _remaining = _left;
    });
  }

  void _tick() {
    // Calculé depuis l'heure de fin : reste juste même si l'app a été
    // mise en arrière-plan.
    final left = _endAt!.difference(widget.clock());
    if (left <= Duration.zero) {
      _onPhaseEnd();
    } else {
      setState(() => _remaining = left);
    }
  }

  void _onPhaseEnd() {
    _timer?.cancel();
    _timer = null;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    final PomodoroPhase next;
    if (_phase == PomodoroPhase.focus) {
      _completed++;
      widget.onFocus?.call(_config.focus, full: true);
      next = _completed % _config.longEvery == 0
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
    } else {
      next = PomodoroPhase.focus;
    }
    _goTo(next);
    if (_config.autoStart) _start();
  }

  void _goTo(PomodoroPhase phase) {
    setState(() {
      _phase = phase;
      _remaining = null;
    });
  }

  /// Crédite les minutes de focus déjà faites si on quitte/saute en cours.
  void _creditPartialFocus() {
    if (_phase != PomodoroPhase.focus) return;
    final minutes = (_total - _left).inMinutes;
    if (minutes > 0) widget.onFocus?.call(minutes, full: false);
  }

  void _skip() {
    _timer?.cancel();
    _timer = null;
    _creditPartialFocus();
    _goTo(
      _phase == PomodoroPhase.focus
          ? PomodoroPhase.shortBreak
          : PomodoroPhase.focus,
    );
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _remaining = null;
    });
  }

  void _exit({bool completeTask = false}) {
    if (_running) _remaining = _endAt!.difference(widget.clock());
    _timer?.cancel();
    _timer = null;
    _creditPartialFocus();
    Navigator.pop<bool>(context, completeTask);
  }

  Future<void> _openSettings() async {
    final settings = SettingsScope.maybeOf(context);
    if (settings == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PomodoroSettingsSheet(settings: settings),
    );
    // Si le minuteur n'a pas démarré, on applique la nouvelle durée.
    if (mounted && !_started) setState(() => _remaining = null);
  }

  String get _clock {
    final s = (_left.inMilliseconds / 1000).ceil();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _phase.isBreak ? scheme.tertiary : scheme.primary;
    final progress = 1 - _left.inMilliseconds / _total.inMilliseconds;
    final todo = widget.todo;
    final cycle = _config.longEvery;
    final filled = _phase == PomodoroPhase.longBreak
        ? cycle
        : _completed % cycle;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: _phase.isBreak
            ? Color.alphaBlend(
                scheme.tertiaryContainer.withValues(alpha: 0.35),
                scheme.surface,
              )
            : null,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Pomodoro'),
          leading: IconButton(
            tooltip: 'Quitter',
            icon: const Icon(Icons.close),
            onPressed: _exit,
          ),
          actions: [
            if (SettingsScope.maybeOf(context) != null)
              IconButton(
                tooltip: 'Réglages du pomodoro',
                icon: const Icon(Icons.tune),
                onPressed: _openSettings,
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (todo != null) ...[
                    Text(
                      todo.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '${_phase.emoji} ${_phase.label}',
                    key: const Key('pomodoro-phase'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(switch (_phase) {
                    PomodoroPhase.focus => 'Une seule chose à la fois.',
                    PomodoroPhase.shortBreak =>
                      "Lève-toi, bois de l'eau, respire.",
                    PomodoroPhase.longBreak =>
                      'Bravo ! Prends une vraie pause.',
                  }, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          color: accent,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                        Center(
                          child: Text(
                            _clock,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Progression dans le cycle : une tomate par session.
                  Tooltip(
                    message:
                        '$_completed pomodoro${_completed > 1 ? 's' : ''} '
                        'pendant cette séance',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < cycle; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Opacity(
                              opacity: i < filled ? 1 : 0.25,
                              child: const Text(
                                '🍅',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Recommencer',
                        onPressed: _started && !_running ? _reset : null,
                        icon: const Icon(Icons.replay),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(150, 52),
                        ),
                        onPressed: _running ? _pause : _start,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(
                          _running
                              ? 'Pause'
                              : _started
                              ? 'Reprendre'
                              : 'Démarrer',
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.outlined(
                        tooltip: _phase.isBreak
                            ? 'Passer la pause'
                            : 'Passer à la pause',
                        onPressed: _skip,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_phase.isBreak)
                    Text(
                      'Pomodoro complet : +${focusXp(_config.focus)} XP',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  if (todo != null && !todo.done) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _exit(completeTask: true),
                      icon: const Icon(Icons.check),
                      label: const Text("J'ai terminé la tâche"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PomodoroSettingsSheet extends StatelessWidget {
  const _PomodoroSettingsSheet({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = settings.pomodoro;
        void set(PomodoroConfig next) => settings.setPomodoro(next);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réglages du pomodoro',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _Stepper(
                  label: 'Focus',
                  value: c.focus,
                  unit: 'min',
                  min: 5,
                  max: 90,
                  step: 5,
                  onChanged: (v) => set(c.copyWith(focus: v)),
                ),
                _Stepper(
                  label: 'Pause courte',
                  value: c.shortBreak,
                  unit: 'min',
                  min: 1,
                  max: 20,
                  onChanged: (v) => set(c.copyWith(shortBreak: v)),
                ),
                _Stepper(
                  label: 'Pause longue',
                  value: c.longBreak,
                  unit: 'min',
                  min: 5,
                  max: 45,
                  step: 5,
                  onChanged: (v) => set(c.copyWith(longBreak: v)),
                ),
                _Stepper(
                  label: 'Pause longue toutes les',
                  value: c.longEvery,
                  unit: 'sessions',
                  min: 2,
                  max: 8,
                  onChanged: (v) => set(c.copyWith(longEvery: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enchaîner automatiquement'),
                  value: c.autoStart,
                  onChanged: (v) => set(c.copyWith(autoStart: v)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: 'Moins',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 82,
          child: Text(
            '$value $unit',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Plus',
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
