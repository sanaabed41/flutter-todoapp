const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

const _weekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche', //
];
const _weekdaysShort = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

const _monthsLong = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', //
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « Jeudi 12 novembre ».
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsLong[d.month - 1]}';

/// En-tête de journée pour l'agenda : « Aujourd'hui », « Demain »,
/// sinon « Samedi 14 nov. ».
String formatDayHeader(DateTime day, {DateTime? now}) {
  final label = formatDueDate(day, now: now);
  if (label == "Aujourd'hui" || label == 'Demain') return label;
  return '${_weekdays[day.weekday - 1]} $label';
}

/// Formate une échéance de façon lisible : « Aujourd'hui », « Demain »,
/// « Hier », « 12 nov. » ou « 12 nov. 2027 » si l'année diffère.
String formatDueDate(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Calcul en UTC pour éviter les décalages liés au changement d'heure.
  final diff = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  switch (diff) {
    case 0:
      return "Aujourd'hui";
    case 1:
      return 'Demain';
    case -1:
      return 'Hier';
  }
  final base = '${due.day} ${_months[due.month - 1]}';
  return due.year == today.year ? base : '$base ${due.year}';
}
