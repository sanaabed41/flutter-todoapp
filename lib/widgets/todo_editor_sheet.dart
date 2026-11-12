import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../services/smart_parser.dart';
import '../utils/date_format.dart';

/// Feuille de saisie pour créer ou modifier une tâche.
/// Renvoie une nouvelle instance de [Todo], ou `null` si l'utilisateur annule.
class TodoEditorSheet extends StatefulWidget {
  const TodoEditorSheet({super.key, this.initial, this.defaultDueDate});

  final Todo? initial;

  /// Échéance proposée pour une nouvelle tâche (ex. jour choisi dans l'agenda).
  final DateTime? defaultDueDate;

  static Future<Todo?> show(
    BuildContext context, {
    Todo? initial,
    DateTime? defaultDueDate,
  }) {
    return showModalBottomSheet<Todo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          TodoEditorSheet(initial: initial, defaultDueDate: defaultDueDate),
    );
  }

  @override
  State<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<TodoEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial?.notes ?? '',
  );
  late Priority _priority = widget.initial?.priority ?? Priority.normal;
  late DateTime? _dueDate = widget.initial != null
      ? widget.initial!.dueDate
      : widget.defaultDueDate;
  String? _error;

  // Saisie intelligente : valeurs choisies à la main (prioritaires sur
  // ce que l'analyse du titre détecte) et dernier résultat d'analyse.
  late Priority _basePriority = _priority;
  late DateTime? _baseDueDate = _dueDate;
  bool _manualPriority = false;
  bool _manualDate = false;
  ParsedTask? _parsed;

  void _onTitleChanged(String text) {
    final parsed = parseTask(text);
    setState(() {
      _error = null;
      _parsed = parsed.hasDetection ? parsed : null;
      if (!_manualDate) _dueDate = parsed.dueDate ?? _baseDueDate;
      if (!_manualPriority) _priority = parsed.priority ?? _basePriority;
    });
  }

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: "Date d'échéance",
    );
    if (picked != null) {
      setState(() {
        _dueDate = _baseDueDate = picked;
        _manualDate = true;
      });
    }
  }

  void _submit() {
    final title = parseTask(_title.text).title;
    if (title.isEmpty) {
      setState(() => _error = 'Le titre est obligatoire');
      return;
    }
    final initial = widget.initial;
    Navigator.pop(
      context,
      Todo(
        id: initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        notes: _notes.text.trim(),
        done: initial?.done ?? false,
        priority: _priority,
        dueDate: _dueDate,
        createdAt: initial?.createdAt,
        completedAt: initial?.completedAt,
        xpAwarded: initial?.xpAwarded ?? 0,
        pomodoros: initial?.pomodoros ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Modifier la tâche' : 'Nouvelle tâche',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('editor-title'),
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Titre',
                hintText: 'Ex : Acheter du pain',
                errorText: _error,
              ),
              onChanged: _onTitleChanged,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 6),
            _SmartHint(parsed: _parsed),
            const SizedBox(height: 12),
            TextField(
              key: const Key('editor-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (facultatif)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Priorité', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Priority>(
              segments: [
                for (final p in Priority.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() {
                _priority = _basePriority = s.first;
                _manualPriority = true;
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueDate == null
                          ? 'Ajouter une échéance'
                          : 'Échéance : ${formatDueDate(_dueDate!)}',
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: "Retirer l'échéance",
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _dueDate = _baseDueDate = null;
                      _manualDate = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Montre ce que la saisie intelligente a compris, ou une astuce.
class _SmartHint extends StatelessWidget {
  const _SmartHint({required this.parsed});

  final ParsedTask? parsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = parsed;

    if (p == null) {
      return Text(
        '🪄 Astuce : écris « demain », « vendredi », « le 25/12 », « urgent »…',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      key: const Key('smart-hint'),
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '🪄 Compris :',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (p.dueDate != null)
          _HintChip(icon: Icons.event, label: formatDueDate(p.dueDate!)),
        if (p.priority != null)
          _HintChip(
            icon: Icons.flag,
            label: 'Priorité ${p.priority!.label.toLowerCase()}',
          ),
        _HintChip(icon: Icons.title, label: '« ${p.title} »'),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
