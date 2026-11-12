import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/progress.dart';
import '../models/todo.dart';
import '../services/todo_storage.dart';
import '../theme/app_theme_data.dart';
import '../theme/app_themes.dart';
import '../widgets/celebration.dart';
import '../widgets/progress_card.dart';
import '../widgets/todo_editor_sheet.dart';
import '../widgets/todo_tile.dart';
import '../services/smart_suggest.dart';
import '../services/workload.dart';
import '../utils/date_format.dart';
import '../widgets/agenda_view.dart';
import '../widgets/overload_banner.dart';
import '../widgets/suggestion_card.dart';
import 'pomodoro_screen.dart';
import 'stats_screen.dart';

enum Filter { all, active, done }

enum SortMode {
  creation('Date de création'),
  dueDate("Date d'échéance"),
  priority('Priorité');

  const SortMode(this.label);
  final String label;
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key, this.storage});

  final TodoStorage? storage;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late final TodoStorage _storage = widget.storage ?? TodoStorage();
  final TextEditingController _search = TextEditingController();

  List<Todo> _todos = [];
  Progress _progress = Progress();
  Filter _filter = Filter.all;
  SortMode _sort = SortMode.creation;
  bool _searching = false;
  bool _loading = true;

  /// 0 = liste, 1 = agenda.
  int _tab = 0;

  /// Jour choisi dans l'agenda : échéance par défaut des nouvelles tâches.
  DateTime? _agendaDay;

  /// Suggestions écartées avec « Autre idée ».
  final Set<String> _skippedSuggestions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final todos = await _storage.load();
    final sort = await _storage.loadSortMode();
    final progress = await _storage.loadProgress();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _progress = progress;
      _sort = SortMode.values.firstWhere(
        (s) => s.name == sort,
        orElse: () => SortMode.creation,
      );
      _loading = false;
    });
  }

  void _update(VoidCallback change) {
    setState(change);
    _storage.save(_todos);
  }

  /// Applique un changement de progression, sauvegarde, puis célèbre
  /// l'XP gagné, un éventuel nouveau niveau et les succès débloqués.
  void _changeProgress(void Function(Progress p) change) {
    final levelBefore = _progress.levelInfo.level;
    final xpBefore = _progress.xp;
    final unlockedBefore = _progress.unlockedAchievements;

    change(_progress);
    _storage.save(_todos);
    _storage.saveProgress(_progress);

    final gained = _progress.xp - xpBefore;
    if (gained <= 0 || !mounted) return;

    final level = _progress.levelInfo;
    final newAchievements = achievements
        .where(
          (a) =>
              !unlockedBefore.contains(a.id) &&
              _progress.unlockedAchievements.contains(a.id),
        )
        .toList();

    if (level.level > levelBefore) {
      HapticFeedback.heavyImpact();
      final newThemes = themesUnlockedBetween(levelBefore, level.level);
      showCelebration(
        context,
        emoji: '🚀',
        title: 'Niveau ${level.level} !',
        lines: [
          'Tu es maintenant « ${level.title} »',
          for (final a in newAchievements) '${a.emoji} Succès : ${a.title}',
          for (final t in newThemes) '${t.emoji} Nouveau thème : ${t.name}',
        ],
        big: true,
      );
    } else if (newAchievements.isNotEmpty) {
      HapticFeedback.mediumImpact();
      showCelebration(
        context,
        emoji: newAchievements.first.emoji,
        title: 'Succès débloqué !',
        lines: [for (final a in newAchievements) a.title, '+$gained XP'],
        big: true,
      );
    } else {
      HapticFeedback.lightImpact();
      showCelebration(context, emoji: '✨', title: '+$gained XP');
    }
  }

  void _toggle(Todo todo, bool done) {
    if (todo.done == done) return;
    setState(
      () => _changeProgress((p) {
        todo.done = done;
        if (done) {
          final now = DateTime.now();
          todo.xpAwarded = xpForTodo(todo, now);
          todo.completedAt = now;
          p.recordCompletion(todo.xpAwarded, now);
        } else {
          p.undoCompletion(todo.xpAwarded, todo.completedAt);
          todo.xpAwarded = 0;
          todo.completedAt = null;
        }
      }),
    );
  }

  /// Ouvre le Pomodoro, lié à une tâche ou libre. Les minutes de focus
  /// sont créditées au fil de l'eau (la célébration s'affiche par-dessus).
  Future<void> _openPomodoro([Todo? todo]) async {
    final completeTask = await PomodoroScreen.open(
      context,
      todo: todo,
      onFocus: (minutes, {required full}) {
        if (!mounted) return;
        setState(
          () => _changeProgress((p) {
            p.recordFocus(minutes, fullPomodoro: full);
            if (full && todo != null) todo.pomodoros++;
          }),
        );
      },
    );
    if (completeTask == true && todo != null && mounted) _toggle(todo, true);
  }

  /// Une suggestion n'a d'intérêt que s'il y a au moins 2 tâches à faire.
  Suggestion? get _suggestion {
    if (_todos.where((t) => !t.done).length < 2) return null;
    var s = suggestNext(_todos, exclude: _skippedSuggestions);
    if (s == null && _skippedSuggestions.isNotEmpty) {
      // On a fait le tour : on recommence depuis la meilleure.
      _skippedSuggestions.clear();
      s = suggestNext(_todos);
    }
    return s;
  }

  Future<void> _openStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(progress: _progress)),
    );
    if (mounted) setState(() {});
  }

  void _setSort(SortMode mode) {
    setState(() => _sort = mode);
    _storage.saveSortMode(mode.name);
  }

  List<Todo> get _visible {
    final query = _search.text.trim().toLowerCase();
    final position = {for (var i = 0; i < _todos.length; i++) _todos[i].id: i};

    final list = _todos.where((t) {
      final matchesFilter = switch (_filter) {
        Filter.all => true,
        Filter.active => !t.done,
        Filter.done => t.done,
      };
      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.notes.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    list.sort((a, b) {
      // Les tâches terminées vont toujours en bas.
      if (a.done != b.done) return a.done ? 1 : -1;
      final byMode = switch (_sort) {
        SortMode.creation => 0,
        SortMode.dueDate => _compareDue(a.dueDate, b.dueDate),
        SortMode.priority => b.priority.index.compareTo(a.priority.index),
      };
      // Départage par l'ordre d'origine pour un tri stable.
      return byMode != 0 ? byMode : position[a.id]!.compareTo(position[b.id]!);
    });
    return list;
  }

  /// Les tâches sans échéance passent après celles qui en ont une.
  static int _compareDue(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int get _doneCount => _todos.where((t) => t.done).length;

  Future<void> _openEditor({Todo? todo}) async {
    final result = await TodoEditorSheet.show(
      context,
      initial: todo,
      // Dans l'agenda, une nouvelle tâche est prévue pour le jour affiché.
      defaultDueDate: _tab == 1
          ? (_agendaDay ?? dateOnly(DateTime.now()))
          : null,
    );
    if (result == null || !mounted) return;
    _update(() {
      if (todo == null) {
        _todos.insert(0, result);
      } else {
        final index = _todos.indexWhere((t) => t.id == todo.id);
        if (index != -1) _todos[index] = result;
      }
    });
  }

  void _showUndo(String message, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Annuler', onPressed: undo),
        ),
      );
  }

  void _delete(Todo todo) {
    final index = _todos.indexOf(todo);
    _update(() => _todos.remove(todo));
    _showUndo(
      '« ${todo.title} » supprimée',
      () => _update(() => _todos.insert(index.clamp(0, _todos.length), todo)),
    );
  }

  void _clearDone() {
    final removed = <(int, Todo)>[
      for (var i = 0; i < _todos.length; i++)
        if (_todos[i].done) (i, _todos[i]),
    ];
    if (removed.isEmpty) return;
    _update(() => _todos.removeWhere((t) => t.done));
    final n = removed.length;
    _showUndo(
      '$n tâche${n > 1 ? 's' : ''} terminée${n > 1 ? 's' : ''} supprimée${n > 1 ? 's' : ''}',
      () => _update(() {
        // Réinsertion dans l'ordre croissant pour retrouver les positions.
        for (final (i, t) in removed) {
          _todos.insert(i.clamp(0, _todos.length), t);
        }
      }),
    );
  }

  int get _capacity => dailyCapacity(_progress);

  void _moveTo(Todo todo, DateTime day) {
    final previous = todo.dueDate;
    _update(() => todo.dueDate = dateOnly(day));
    _showUndo(
      '« ${todo.title} » déplacée à ${formatDayHeader(day).toLowerCase()}',
      () => _update(() => todo.dueDate = previous),
    );
  }

  Future<void> _rebalance() async {
    final moves = planRebalance(_todos, _capacity);
    if (moves.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_fix_high),
        title: const Text('Rééquilibrer ma semaine'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Je déplace les tâches les moins importantes vers des jours '
                'plus calmes (environ $_capacity tâches/jour). Les tâches de '
                'priorité haute ne bougent pas.',
              ),
              const SizedBox(height: 12),
              for (final m in moves)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.east),
                  title: Text(m.todo.title),
                  subtitle: Text(
                    '${m.from == null ? '' : formatDayHeader(m.from!)} → ${formatDayHeader(m.to)}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Déplacer ${moves.length} tâche${moves.length > 1 ? 's' : ''}',
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _update(() {
      for (final m in moves) {
        m.todo.dueDate = m.to;
      }
    });
    final n = moves.length;
    _showUndo(
      '$n tâche${n > 1 ? 's' : ''} déplacée${n > 1 ? 's' : ''}',
      () => _update(() {
        for (final m in moves) {
          m.todo.dueDate = m.from;
        }
      }),
    );
  }

  /// Bannière de surcharge pour la semaine à venir (ou `null`).
  Widget? _buildOverloadBanner() {
    final capacity = _capacity;
    final overloaded = upcomingLoad(
      _todos,
      capacity,
      days: 7,
    ).where((l) => l.overloaded).toList();
    if (overloaded.isEmpty) return null;
    return OverloadBanner(
      overloaded: overloaded,
      canRebalance: planRebalance(_todos, capacity).isNotEmpty,
      onRebalance: _rebalance,
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  Widget _buildTitle(ThemeData theme) {
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 5 => 'Bonne nuit',
      < 12 => 'Bonjour',
      < 18 => 'Bon après-midi',
      _ => 'Bonsoir',
    };
    final (title, subtitle) = _tab == 0
        ? ('$greeting 👋', formatLongDate(now))
        : ('Mon agenda', "Ta semaine en un coup d'œil");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subtitle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: _searching ? kToolbarHeight : 76,
      title: _searching
          ? TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher…',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            )
          : _buildTitle(Theme.of(context)),
      actions: [
        IconButton(
          tooltip: 'Pomodoro',
          icon: const Icon(Icons.timer_outlined),
          onPressed: () => _openPomodoro(),
        ),
        if (_tab == 0) ...[
          IconButton(
            tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          PopupMenuButton<SortMode>(
            tooltip: 'Trier',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: _setSort,
            itemBuilder: (_) => [
              for (final mode in SortMode.values)
                CheckedPopupMenuItem(
                  value: mode,
                  checked: mode == _sort,
                  child: Text(mode.label),
                ),
            ],
          ),
          if (_doneCount > 0)
            IconButton(
              tooltip: 'Supprimer les tâches terminées',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: _clearDone,
            ),
        ],
      ],
    );
  }

  Widget _buildSummary(ColorScheme scheme) {
    final theme = Theme.of(context);
    final total = _todos.length;
    final remaining = total - _doneCount;
    final overdue = _todos.where((t) => t.isOverdue()).length;

    final String label;
    if (total == 0) {
      label = 'Aucune tâche pour le moment';
    } else if (remaining == 0) {
      label = 'Tout est fait 🎉';
    } else {
      label =
          '$remaining tâche${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mes tâches', style: theme.textTheme.titleLarge),
              const Spacer(),
              if (overdue > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$overdue en retard',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (total > 0)
                Text(
                  '${(_doneCount * 100 / total).round()} %',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _doneCount / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Filter>(
                segments: const [
                  ButtonSegment(value: Filter.all, label: Text('Toutes')),
                  ButtonSegment(value: Filter.active, label: Text('À faire')),
                  ButtonSegment(value: Filter.done, label: Text('Terminées')),
                ],
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    final theme = Theme.of(context);
    final searching = _search.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.task_alt_rounded,
              size: 46,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? 'Aucun résultat' : 'Aucune tâche ici',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            searching
                ? 'Essaie avec un autre mot.'
                : 'Appuie sur « Ajouter » pour commencer.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    final suggestion = _loading ? null : _suggestion;

    return Scaffold(
      appBar: _buildAppBar(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          if (_searching) _toggleSearch();
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Liste',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tab == 1
          ? AgendaView(
              todos: _todos,
              capacity: _capacity,
              banner: _buildOverloadBanner(),
              onToggle: _toggle,
              onEdit: (t) => _openEditor(todo: t),
              onFocus: _openPomodoro,
              onMove: _moveTo,
              onSelectedDayChanged: (d) => _agendaDay = d,
            )
          // Tout défile ensemble (cartes + liste) : rien ne déborde sur
          // les petits écrans ou quand le clavier est ouvert.
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ProgressCard(progress: _progress, onTap: _openStats),
                      if (!_searching) ?_buildOverloadBanner(),
                      if (!_searching && suggestion != null)
                        SuggestionCard(
                          suggestion: suggestion,
                          onStart: () => _openPomodoro(suggestion.todo),
                          onSkip: () => setState(
                            () => _skippedSuggestions.add(suggestion.todo.id),
                          ),
                        ),
                      _buildSummary(scheme),
                    ],
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: _buildEmpty(scheme),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 88),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final todo = visible[i];
                        return Dismissible(
                          key: ValueKey(todo.id),
                          direction: DismissDirection.endToStart,
                          background: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Supprimer',
                                    style: TextStyle(
                                      color: scheme.onError,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.delete_outline,
                                    color: scheme.onError,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onDismissed: (_) => _delete(todo),
                          child: TodoTile(
                            todo: todo,
                            onToggle: (v) => _toggle(todo, v),
                            onTap: () => _openEditor(todo: todo),
                            onFocus: () => _openPomodoro(todo),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
