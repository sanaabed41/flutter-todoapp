import '../models/todo.dart';

/// Résultat de l'analyse d'une saisie en langage naturel.
class ParsedTask {
  const ParsedTask({required this.title, this.dueDate, this.priority});

  /// Titre nettoyé (sans « demain », « urgent », etc.).
  final String title;
  final DateTime? dueDate;
  final Priority? priority;

  bool get hasDetection => dueDate != null || priority != null;
}

// Frontières de mot compatibles avec les accents (\b ne gère que l'ASCII).
const _l = r'(?<![\p{L}\d])';
const _r = r'(?![\p{L}\d])';
// Petits mots qui précèdent souvent une date et qu'on retire avec elle.
const _prep = r"(?:(?:pour|avant|d['’]ici|jusqu['’]à|le|ce|cette)\s+)?";

const _weekdays = {
  'lundi': 1,
  'mardi': 2,
  'mercredi': 3,
  'jeudi': 4,
  'vendredi': 5,
  'samedi': 6,
  'dimanche': 7,
};

const _months = {
  'janvier': 1,
  'février': 2,
  'fevrier': 2,
  'mars': 3,
  'avril': 4,
  'mai': 5,
  'juin': 6,
  'juillet': 7,
  'août': 8,
  'aout': 8,
  'septembre': 9,
  'octobre': 10,
  'novembre': 11,
  'décembre': 12,
  'decembre': 12,
};

RegExp _re(String pattern) =>
    RegExp('$_l$_prep(?:$pattern)$_r', caseSensitive: false, unicode: true);

typedef _DateRule = (RegExp, DateTime? Function(Match m, DateTime today));

DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Construit une date valide, ou `null` (ex. 31/02).
DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final date = DateTime(y, m, d);
  return date.month == m && date.day == d ? date : null;
}

/// Prochaine occurrence d'un jour/mois (cette année, ou l'an prochain
/// si la date est déjà passée).
DateTime? _nextDayMonth(int day, int month, DateTime today, [int? year]) {
  if (year != null) return _validDate(year, month, day);
  final thisYear = _validDate(today.year, month, day);
  if (thisYear != null && !thisYear.isBefore(today)) return thisYear;
  return _validDate(today.year + 1, month, day);
}

final List<_DateRule> _dateRules = [
  (_re(r"apr[eè]s[- ]demain"), (m, t) => _plusDays(t, 2)),
  (_re(r"demain(?:\s+(?:matin|midi|soir))?"), (m, t) => _plusDays(t, 1)),
  (
    _re(r"aujourd['’]hui|ce\s+(?:matin|midi|soir)|tout\s+de\s+suite"),
    (m, t) => t,
  ),
  (_re(r"dans\s+(\d{1,3})\s+jours?"), (m, t) => _plusDays(t, int.parse(m[1]!))),
  (
    _re(r"dans\s+(\d{1,2})\s+semaines?"),
    (m, t) => _plusDays(t, 7 * int.parse(m[1]!)),
  ),
  (
    _re(r"dans\s+une\s+semaine|la\s+semaine\s+prochaine"),
    (m, t) => _plusDays(t, 7),
  ),
  (
    _re('(${_weekdays.keys.join('|')})(?:\\s+prochain)?'),
    (m, t) {
      final target = _weekdays[m[1]!.toLowerCase()]!;
      var diff = (target - t.weekday) % 7;
      if (diff == 0) diff = 7; // « lundi » un lundi → lundi prochain
      return _plusDays(t, diff);
    },
  ),
  (
    _re('(\\d{1,2})(?:er)?\\s+(${_months.keys.join('|')})(?:\\s+(\\d{4}))?'),
    (m, t) => _nextDayMonth(
      int.parse(m[1]!),
      _months[m[2]!.toLowerCase()]!,
      t,
      m[3] == null ? null : int.parse(m[3]!),
    ),
  ),
  (
    _re(r"(\d{1,2})[/.](\d{1,2})(?:[/.](\d{2,4}))?"),
    (m, t) {
      int? year = m[3] == null ? null : int.parse(m[3]!);
      if (year != null && year < 100) year += 2000;
      return _nextDayMonth(int.parse(m[1]!), int.parse(m[2]!), t, year);
    },
  ),
  (
    RegExp(
      '$_l(?:(?:pour|avant)\\s+)?le\\s+(\\d{1,2})(?:er)?$_r(?![/.]\\d)',
      caseSensitive: false,
      unicode: true,
    ),
    (m, t) {
      final day = int.parse(m[1]!);
      final thisMonth = _validDate(t.year, t.month, day);
      if (thisMonth != null && !thisMonth.isBefore(t)) return thisMonth;
      return _validDate(t.year, t.month + 1, day) ??
          _validDate(t.year, t.month + 2, day);
    },
  ),
];

final _lowPriority = RegExp(
  "$_l(?:pas\\s+urgent|priorit[ée]\\s+basse|un\\s+de\\s+ces\\s+jours)$_r"
  r"|#bas(?:se)?(?![\p{L}\d])",
  caseSensitive: false,
  unicode: true,
);

final _highPriority = RegExp(
  "$_l(?:urgente?|importante?|asap|priorit[ée]\\s+haute)$_r"
  r"|#urgent(?![\p{L}\d])|(?<!\S)!+(?!\S)|!{2,}",
  caseSensitive: false,
  unicode: true,
);

/// Analyse une saisie comme « Appeler Paul demain urgent » et en extrait
/// l'échéance et la priorité. Fonctionne hors ligne, sans IA externe.
ParsedTask parseTask(String input, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  var text = input;
  DateTime? due;
  Priority? priority;

  for (final (re, toDate) in _dateRules) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    final date = toDate(m, today);
    if (date == null) continue;
    due = date;
    text = text.replaceRange(m.start, m.end, ' ');
    break;
  }

  // « pas urgent » doit être testé avant « urgent ».
  final low = _lowPriority.firstMatch(text);
  if (low != null) {
    priority = Priority.low;
    text = text.replaceRange(low.start, low.end, ' ');
  } else if (_highPriority.hasMatch(text)) {
    priority = Priority.high;
    text = text.replaceAll(_highPriority, ' ');
  }

  var title = text
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'^[\s,;:\-–]+|[\s,;:\-–]+$'), '')
      .trim();
  // Si l'utilisateur n'a tapé que « demain », on garde le texte d'origine.
  if (title.isEmpty) title = input.trim();

  return ParsedTask(title: title, dueDate: due, priority: priority);
}
