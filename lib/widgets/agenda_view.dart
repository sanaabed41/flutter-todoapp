import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../services/workload.dart';
import '../utils/date_format.dart';
import 'todo_tile.dart';

/// Vue calendrier : frise des prochains jours avec leur charge, puis les
/// tâches regroupées par jour. Appui long sur une tâche pour la glisser
/// vers un autre jour de la frise.
class AgendaView extends StatefulWidget {
  const AgendaView({
    super.key,
    required this.todos,
    required this.capacity,
    required this.onToggle,
    required this.onEdit,
    required this.onFocus,
    required this.onMove,
    required this.onSelectedDayChanged,
    this.banner,
  });

  final List<Todo> todos;
  final int capacity;
  final void Function(Todo todo, bool done) onToggle;
  final ValueChanged<Todo> onEdit;
  final ValueChanged<Todo> onFocus;
  final void Function(Todo todo, DateTime day) onMove;

  /// Jour sélectionné dans la frise (`null` = tout voir). Sert à
  /// pré-remplir l'échéance des nouvelles tâches.
  final ValueChanged<DateTime?> onSelectedDayChanged;
  final Widget? banner;

  static const days = 14;

  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  int? _selected;

  void _select(int? index, List<DayLoad> loads) {
    setState(() => _selected = _selected == index ? null : index);
    widget.onSelectedDayChanged(
      _selected == null ? null : loads[_selected!].day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loads = upcomingLoad(
      widget.todos,
      widget.capacity,
      days: AgendaView.days,
    );
    final today = loads.first.day;
    final active = widget.todos.where((t) => !t.done).toList();

    final overdue = active.where((t) => t.isOverdue()).toList()
      ..sort(compareImportance);
    final later =
        active
            .where(
              (t) =>
                  t.dueDate != null &&
                  daysBetween(today, t.dueDate!) >= AgendaView.days,
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final undated = active.where((t) => t.dueDate == null).toList()
      ..sort(compareImportance);

    List<Todo> dayTasks(int i) => loads[i].tasks
        .where((t) => daysBetween(today, t.dueDate!) == i)
        .toList();

    final sections = <Widget>[];
    void addSection(
      String title,
      List<Todo> tasks, {
      DayLoad? load,
      String? empty,
      Color? color,
    }) {
      if (tasks.isEmpty && empty == null) return;
      sections.add(_SectionHeader(title: title, load: load, color: color));
      if (tasks.isEmpty) {
        sections.add(_EmptyDay(text: empty!));
      }
      for (final t in tasks) {
        sections.add(
          _DraggableTile(
            key: ValueKey('agenda-${t.id}'),
            todo: t,
            onToggle: (v) => widget.onToggle(t, v),
            onTap: () => widget.onEdit(t),
            onFocus: () => widget.onFocus(t),
          ),
        );
      }
    }

    final scheme = Theme.of(context).colorScheme;
    if (_selected == null) {
      addSection('En retard', overdue, color: scheme.error);
      for (var i = 0; i < AgendaView.days; i++) {
        addSection(
          formatDayHeader(loads[i].day),
          dayTasks(i),
          load: loads[i],
          empty: i <= 1 ? 'Rien de prévu' : null,
        );
      }
      addSection('Plus tard', later);
      addSection('Sans date', undated);
    } else {
      final i = _selected!;
      if (i == 0) addSection('En retard', overdue, color: scheme.error);
      addSection(
        formatDayHeader(loads[i].day),
        dayTasks(i),
        load: loads[i],
        empty: 'Rien de prévu ce jour-là',
      );
    }

    return Column(
      children: [
        _WeekStrip(
          loads: loads,
          selected: _selected,
          onSelect: (i) => _select(i, loads),
          onDrop: widget.onMove,
        ),
        ?widget.banner,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(Icons.speed, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ton rythme : ~${widget.capacity} tâches/jour',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              if (_selected != null)
                TextButton(
                  onPressed: () => _select(null, loads),
                  child: const Text('Tout voir'),
                ),
            ],
          ),
        ),
        Expanded(
          child: sections.isEmpty
              ? Center(
                  child: Text(
                    'Aucune tâche à planifier',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: sections,
                ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.loads,
    required this.selected,
    required this.onSelect,
    required this.onDrop,
  });

  final List<DayLoad> loads;
  final int? selected;
  final ValueChanged<int> onSelect;
  final void Function(Todo todo, DateTime day) onDrop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        itemCount: loads.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => DragTarget<Todo>(
          onWillAcceptWithDetails: (d) =>
              d.data.dueDate == null ||
              daysBetween(loads[i].day, d.data.dueDate!) != 0,
          onAcceptWithDetails: (d) => onDrop(d.data, loads[i].day),
          builder: (context, candidates, _) => _DayChip(
            key: Key('day-chip-$i'),
            load: loads[i],
            isToday: i == 0,
            selected: selected == i,
            highlighted: candidates.isNotEmpty,
            onTap: () => onSelect(i),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.load,
    required this.isToday,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final DayLoad load;
  final bool isToday;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final barColor = load.overloaded
        ? (selected ? scheme.onPrimary : scheme.error)
        : (selected ? scheme.onPrimary : scheme.primary);
    final fraction = (load.count / load.capacity).clamp(0.0, 1.0);

    return Tooltip(
      message:
          '${formatDayHeader(load.day)} : ${load.count} tâche'
          '${load.count > 1 ? 's' : ''}${load.overloaded ? ' (surchargé)' : ''}',
      child: Material(
        color: highlighted
            ? scheme.tertiaryContainer
            : selected
            ? scheme.primary
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: isToday && !selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.primary, width: 1.5),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday ? 'Auj.' : weekdayShort(load.day),
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
                Text(
                  '${load.day.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Jauge de charge : pleine = rythme habituel atteint.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 4,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    if (load.overloaded) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.priority_high, size: 10, color: barColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.load, this.color});

  final String title;
  final DayLoad? load;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = load;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color ?? scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (l != null && l.count > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (l.overloaded)
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: scheme.error,
                  ),
                const SizedBox(width: 4),
                Text(
                  '${l.count} / ${l.capacity}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: l.overloaded
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    fontWeight: l.overloaded ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.outline,
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

class _DraggableTile extends StatelessWidget {
  const _DraggableTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onFocus,
  });

  final Todo todo;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final tile = TodoTile(
      todo: todo,
      onToggle: onToggle,
      onTap: onTap,
      onFocus: onFocus,
    );
    final scheme = Theme.of(context).colorScheme;

    return LongPressDraggable<Todo>(
      data: todo,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                todo.title,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}
