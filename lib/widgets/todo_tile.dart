import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../theme/app_theme_data.dart';
import '../utils/date_format.dart';

/// Carte d'une tâche : case ronde (colorée selon la priorité), titre,
/// notes, puis petites pastilles (échéance, priorité, pomodoros).
class TodoTile extends StatelessWidget {
  const TodoTile({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = todo.isOverdue();
    final priorityColor = switch (todo.priority) {
      Priority.high => scheme.error,
      Priority.normal => scheme.outline,
      Priority.low => scheme.outlineVariant,
    };

    final meta = <Widget>[
      if (todo.dueDate != null)
        _MetaChip(
          icon: overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
          label: overdue
              ? 'En retard · ${formatDueDate(todo.dueDate!)}'
              : formatDueDate(todo.dueDate!),
          foreground: overdue ? scheme.onErrorContainer : null,
          background: overdue ? scheme.errorContainer : null,
        ),
      if (todo.priority == Priority.high)
        Tooltip(
          message: 'Priorité haute',
          child: _MetaChip(
            icon: Icons.flag,
            foreground: scheme.error,
            background: scheme.error.withValues(alpha: 0.12),
          ),
        ),
      if (todo.priority == Priority.low)
        const Tooltip(
          message: 'Priorité basse',
          child: _MetaChip(icon: Icons.outlined_flag),
        ),
      if (todo.pomodoros > 0)
        _MetaChip(emoji: '🍅', label: '${todo.pomodoros}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: todo.done ? 0.6 : 1,
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  Checkbox(
                    value: todo.done,
                    side: BorderSide(color: priorityColor, width: 2),
                    onChanged: (v) => onToggle(v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15,
                              decoration: todo.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.done ? scheme.outline : null,
                            ),
                          ),
                          if (todo.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                todo.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (meta.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: meta,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!todo.done)
                    IconButton(
                      tooltip: 'Lancer un pomodoro',
                      color: scheme.primary,
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      iconSize: 30,
                      onPressed: onFocus,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    this.icon,
    this.emoji,
    this.label,
    this.foreground,
    this.background,
  });

  final IconData? icon;
  final String? emoji;
  final String? label;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 5 : 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: fg),
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 11)),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
