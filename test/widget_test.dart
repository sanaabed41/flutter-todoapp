import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo_app/main.dart';
import 'package:todo_app/models/pomodoro_config.dart';
import 'package:todo_app/models/progress.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/screens/stats_screen.dart';
import 'package:todo_app/screens/themes_screen.dart';
import 'package:todo_app/screens/pomodoro_screen.dart';
import 'package:todo_app/services/smart_parser.dart';
import 'package:todo_app/services/smart_suggest.dart';
import 'package:todo_app/services/workload.dart';
import 'package:todo_app/theme/app_themes.dart';
import 'package:todo_app/widgets/todo_tile.dart';
import 'package:todo_app/utils/date_format.dart';

Future<void> addTodo(
  WidgetTester tester,
  String title, {
  String? notes,
  Priority? priority,
}) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('editor-title')), title);
  if (notes != null) {
    await tester.enterText(find.byKey(const Key('editor-notes')), notes);
  }
  if (priority != null) {
    await tester.tap(find.text(priority.label));
    await tester.pump();
  }
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ajouter, cocher et supprimer une tâche', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    expect(find.text('Aucune tâche ici'), findsOneWidget);

    await addTodo(tester, 'Acheter du pain', notes: 'Boulangerie du coin');
    expect(find.text('Acheter du pain'), findsOneWidget);
    expect(find.text('Boulangerie du coin'), findsOneWidget);
    expect(find.text('1 tâche restante'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Tout est fait 🎉'), findsOneWidget);

    await tester.drag(find.text('Acheter du pain'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Aucune tâche ici'), findsOneWidget);
  });

  testWidgets('le titre vide est refusé', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Le titre est obligatoire'), findsOneWidget);
  });

  testWidgets('modifier une tâche en la touchant', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Appeler maman');

    await tester.tap(find.text('Appeler maman'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la tâche'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('editor-title')),
      'Appeler papa',
    );
    await tester.tap(find.text('Haute'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Appeler papa'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
  });

  testWidgets('recherche et tri par priorité', (tester) async {
    // Écran plus haut : les 3 tâches doivent être visibles en même temps.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Faire les courses', priority: Priority.low);
    await addTodo(tester, 'Payer le loyer', priority: Priority.high);
    await addTodo(tester, 'Lire un livre');

    // Tri par priorité : haute > normale > basse.
    await tester.tap(find.byTooltip('Trier'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is CheckedPopupMenuItem &&
            w.value.toString().endsWith('priority'),
      ),
    );
    await tester.pumpAndSettle();
    final ys = ['Payer le loyer', 'Lire un livre', 'Faire les courses']
        .map((t) => tester.getTopLeft(find.widgetWithText(TodoTile, t)).dy)
        .toList();
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);

    // Recherche.
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'loyer');
    await tester.pump();
    expect(find.text('Payer le loyer'), findsOneWidget);
    expect(find.text('Lire un livre'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Aucun résultat'), findsOneWidget);
  });

  testWidgets('supprimer les terminées puis annuler', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Tâche A');
    await addTodo(tester, 'Tâche B');

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer les tâches terminées'));
    await tester.pumpAndSettle();
    expect(find.text('Tâche B'), findsNothing);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Tâche B'), findsOneWidget);
  });

  testWidgets('tâche en retard signalée', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'todos': jsonEncode([
        Todo(id: '1', title: 'Rendre le rapport', dueDate: yesterday).toJson(),
      ]),
    });
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    expect(find.text('1 en retard'), findsOneWidget);
    expect(find.text('En retard · Hier'), findsOneWidget);
  });

  test('lecture des anciennes données sans priorité ni échéance', () {
    final t = Todo.fromJson({'id': 'x', 'title': 'Ancienne', 'done': true});
    expect(t.priority, Priority.normal);
    expect(t.dueDate, isNull);
    expect(t.notes, '');
    expect(t.done, isTrue);
  });

  test('formatDueDate', () {
    final now = DateTime(2026, 11, 12, 15);
    expect(formatDueDate(DateTime(2026, 11, 12), now: now), "Aujourd'hui");
    expect(formatDueDate(DateTime(2026, 11, 13), now: now), 'Demain');
    expect(formatDueDate(DateTime(2026, 11, 11), now: now), 'Hier');
    expect(formatDueDate(DateTime(2026, 12, 25), now: now), '25 déc.');
    expect(formatDueDate(DateTime(2027, 1, 3), now: now), '3 janv. 2027');
  });

  testWidgets('cocher donne de l\'XP, décocher les retire', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Urgent', priority: Priority.high);

    expect(find.text('0 / 100 XP'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('Succès débloqué !'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('20 / 100 XP'), findsOneWidget);
    expect(find.text('1 j'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('0 / 100 XP'), findsOneWidget);
  });

  testWidgets('passage de niveau et écran de progression', (tester) async {
    SharedPreferences.setMockInitialValues({
      'progress': jsonEncode(Progress(xp: 95, completedCount: 3).toJson()),
    });
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Dernière ligne droite');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('Niveau 2 !'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progress-card')));
    await tester.pumpAndSettle();
    expect(find.text('Ma progression'), findsOneWidget);
    final statsList = find
        .descendant(
          of: find.byType(StatsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('7 derniers jours'),
      200,
      scrollable: statsList,
    );
    expect(find.text('7 derniers jours'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Premier pas'),
      200,
      scrollable: statsList,
    );
    expect(find.text('Premier pas'), findsOneWidget);
  });

  testWidgets('mode focus : démarrer, quitter et gagner les minutes', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Réviser');

    await tester.tap(find.byTooltip('Lancer un pomodoro'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.text('Démarrer'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.tap(find.byTooltip('Quitter'));
    await tester.pumpAndSettle();
    expect(find.text('Réviser'), findsOneWidget);
  });

  group('Progress', () {
    test('niveaux', () {
      expect(LevelInfo.fromXp(0).level, 1);
      expect(LevelInfo.fromXp(99).level, 1);
      expect(LevelInfo.fromXp(100).level, 2);
      expect(LevelInfo.fromXp(300).level, 3);
      expect(LevelInfo.fromXp(300).xpIntoLevel, 0);
    });

    test('série de jours', () {
      final p = Progress();
      final now = DateTime(2026, 11, 12, 10);
      p.recordCompletion(10, DateTime(2026, 11, 10, 9));
      p.recordCompletion(10, DateTime(2026, 11, 11, 9));
      expect(p.currentStreak(now), 2); // aujourd'hui pas encore fait
      p.recordCompletion(10, now);
      expect(p.currentStreak(now), 3);
      expect(p.bestStreak, 3);
      expect(p.currentStreak(DateTime(2026, 11, 14)), 0);
    });

    test('XP selon priorité et bonus de ponctualité', () {
      final at = DateTime(2026, 11, 12, 18);
      expect(xpForTodo(Todo(id: 'a', title: 'a'), at), 10);
      expect(
        xpForTodo(
          Todo(id: 'b', title: 'b', priority: Priority.high, dueDate: at),
          at,
        ),
        25,
      );
      expect(
        xpForTodo(
          Todo(
            id: 'c',
            title: 'c',
            priority: Priority.low,
            dueDate: DateTime(2026, 11, 1),
          ),
          at,
        ),
        5,
      );
    });
  });

  testWidgets('thèmes : verrouillés selon le niveau, sélection sauvegardée', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      // 100 XP = niveau 2 → Indigo et Émeraude débloqués.
      'progress': jsonEncode(Progress(xp: 100).toJson()),
    });
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progress-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thèmes'));
    await tester.pumpAndSettle();

    expect(find.text('2 / ${appThemes.length} débloqués'), findsOneWidget);
    expect(find.text('Niveau 3 requis'), findsOneWidget);

    // Un thème verrouillé ne s'applique pas.
    await tester.ensureVisible(find.byKey(const Key('theme-coral')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-coral')));
    await tester.pumpAndSettle();
    expect(find.text('Actif'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeId'), isNull);

    await tester.ensureVisible(find.byKey(const Key('theme-emerald')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-emerald')));
    await tester.pumpAndSettle();
    expect(prefs.getString('themeId'), 'emerald');

    await tester.scrollUntilVisible(
      find.text('Sombre'),
      -200,
      scrollable: find
          .descendant(
            of: find.byType(ThemesScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(prefs.getString('themeMode'), 'dark');
    expect(
      Theme.of(tester.element(find.text('Sombre'))).brightness,
      Brightness.dark,
    );
  });

  test('thèmes débloqués entre deux niveaux', () {
    expect(themesUnlockedBetween(1, 2).map((t) => t.id), ['emerald']);
    expect(themesUnlockedBetween(2, 4).map((t) => t.id), ['coral', 'lavender']);
    expect(themesUnlockedBetween(4, 5), isEmpty);
    expect(themeById('inconnu').id, 'indigo');
  });

  group('Saisie intelligente', () {
    // Jeudi 12 novembre 2026.
    final now = DateTime(2026, 11, 12, 10);
    ParsedTask p(String s) => parseTask(s, now: now);

    test('date relative et priorité', () {
      final r = p('Appeler Paul demain urgent');
      expect(r.title, 'Appeler Paul');
      expect(r.dueDate, DateTime(2026, 11, 13));
      expect(r.priority, Priority.high);
    });

    test('jour de la semaine avec préposition', () {
      final r = p('Rendre le rapport avant vendredi');
      expect(r.title, 'Rendre le rapport');
      expect(r.dueDate, DateTime(2026, 11, 13));
      expect(p('Sport jeudi').dueDate, DateTime(2026, 11, 19));
      expect(p('Courses lundi prochain').dueDate, DateTime(2026, 11, 16));
    });

    test('dates explicites', () {
      expect(p('Dentiste le 25/12').dueDate, DateTime(2026, 12, 25));
      expect(p('Payer le loyer le 3').dueDate, DateTime(2026, 12, 3));
      expect(p('Payer le loyer le 3').title, 'Payer le loyer');
      expect(p('Fête le 5 janvier').dueDate, DateTime(2027, 1, 5));
      expect(p('Ménage après-demain').dueDate, DateTime(2026, 11, 14));
      expect(p('Réviser dans 3 jours').dueDate, DateTime(2026, 11, 15));
      expect(p('Voyage dans 2 semaines').dueDate, DateTime(2026, 11, 26));
      expect(p('Rien le 31/02').dueDate, isNull);
    });

    test('priorités', () {
      final low = p('Ranger le garage pas urgent');
      expect(low.priority, Priority.low);
      expect(low.title, 'Ranger le garage');
      expect(p('Payer facture !').priority, Priority.high);
      expect(p('Payer facture !!').title, 'Payer facture');
      expect(p('Projet important').priority, Priority.high);
    });

    test('rien à détecter', () {
      final r = p('Acheter du pain');
      expect(r.hasDetection, isFalse);
      expect(r.title, 'Acheter du pain');
      // « le » seul ou un mot contenant « mardi » ne sont pas des dates.
      expect(p('Ranger le garage').hasDetection, isFalse);
      expect(p('Lire Mardigras').hasDetection, isFalse);
      expect(p('demain').title, 'demain');
    });
  });

  testWidgets("saisie intelligente dans l'éditeur", (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('editor-title')),
      'Appeler Paul demain urgent',
    );
    await tester.pump();
    expect(find.byKey(const Key('smart-hint')), findsOneWidget);
    expect(find.text('Échéance : Demain'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Appeler Paul'), findsOneWidget);
    expect(find.text('Demain'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
  });

  group('Suggestion', () {
    final now = DateTime(2026, 11, 12, 10);

    test('le retard passe avant la priorité', () {
      final s = suggestNext([
        Todo(id: 'a', title: 'Haute', priority: Priority.high, createdAt: now),
        Todo(
          id: 'b',
          title: 'En retard',
          dueDate: DateTime(2026, 11, 10),
          createdAt: now,
        ),
        Todo(id: 'c', title: 'Finie', done: true, createdAt: now),
      ], now: now)!;
      expect(s.todo.id, 'b');
      expect(s.reason, contains('En retard de 2 jours'));
    });

    test('exclusions et liste vide', () {
      final todos = [
        Todo(id: 'a', title: 'A', priority: Priority.high, createdAt: now),
        Todo(id: 'b', title: 'B', createdAt: now),
      ];
      expect(suggestNext(todos, now: now)!.todo.id, 'a');
      expect(suggestNext(todos, now: now, exclude: {'a'})!.todo.id, 'b');
      expect(suggestNext([], now: now), isNull);
    });
  });

  testWidgets('carte de suggestion : autre idée', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Tâche normale');
    await addTodo(tester, 'Payer le loyer', priority: Priority.high);

    final card = find.byKey(const Key('suggestion-card'));
    expect(
      find.descendant(of: card, matching: find.text('Payer le loyer')),
      findsOneWidget,
    );
    await tester.tap(find.text('Autre idée'));
    await tester.pump();
    expect(
      find.descendant(of: card, matching: find.text('Tâche normale')),
      findsOneWidget,
    );
  });

  testWidgets('pomodoro : focus → pause courte → focus, minutes créditées', (
    tester,
  ) async {
    var fakeNow = DateTime(2026, 11, 12, 10);
    final credited = <(int, bool)>[];
    final todo = Todo(id: 't', title: 'Réviser');

    await tester.pumpWidget(
      MaterialApp(
        home: PomodoroScreen(
          todo: todo,
          clock: () => fakeNow,
          onFocus: (m, {required full}) => credited.add((m, full)),
        ),
      ),
    );
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('🍅 Focus'), findsOneWidget);

    await tester.tap(find.text('Démarrer'));
    await tester.pump();
    fakeNow = fakeNow.add(const Duration(minutes: 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('15:00'), findsOneWidget);

    fakeNow = fakeNow.add(const Duration(minutes: 15));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('☕ Pause courte'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(credited, [(25, true)]);

    // Passer la pause → retour au focus.
    await tester.tap(find.byTooltip('Passer la pause'));
    await tester.pump();
    expect(find.text('🍅 Focus'), findsOneWidget);

    // Focus interrompu après 7 min : minutes partielles créditées.
    await tester.tap(find.text('Démarrer'));
    await tester.pump();
    fakeNow = fakeNow.add(const Duration(minutes: 7));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.tap(find.byTooltip('Passer à la pause'));
    await tester.pump();
    expect(credited, [(25, true), (7, false)]);
  });

  test('réglages du pomodoro : sauvegarde et valeurs par défaut', () {
    const c = PomodoroConfig();
    expect(c.longEvery, 4);
    final restored = PomodoroConfig.fromJson(
      c.copyWith(focus: 50, autoStart: true).toJson(),
    );
    expect(restored.focus, 50);
    expect(restored.autoStart, isTrue);
    expect(restored.shortBreak, 5);
  });

  group('Charge de travail', () {
    final now = DateTime(2026, 11, 12, 10);
    final today = DateTime(2026, 11, 12);
    Todo t(String id, int inDays, [Priority p = Priority.normal]) => Todo(
      id: id,
      title: id,
      priority: p,
      dueDate: addDays(today, inDays),
      createdAt: DateTime(2026, 11, 1, 0, 0, int.parse(id.substring(1))),
    );

    test('rythme : défaut sans historique, sinon moyenne des jours actifs', () {
      expect(dailyCapacity(Progress(), now: now), defaultCapacity);
      final p = Progress();
      for (final (day, n) in [(10, 4), (11, 6), (12, 5)]) {
        for (var i = 0; i < n; i++) {
          p.recordCompletion(10, DateTime(2026, 11, day, 9));
        }
      }
      expect(dailyCapacity(p, now: now), 5);
    });

    test('les tâches en retard comptent pour aujourd\'hui', () {
      final loads = upcomingLoad(
        [t('t1', -2), t('t2', 0), t('t3', 1)],
        3,
        now: now,
        days: 7,
      );
      expect(loads[0].count, 2);
      expect(loads[1].count, 1);
    });

    test(
      'rééquilibrage : déplace les moins importantes, jamais les hautes',
      () {
        final todos = [
          t('t1', 0, Priority.high),
          t('t2', 0, Priority.high),
          t('t3', 0),
          t('t4', 0, Priority.low),
          t('t5', 0),
          t('t6', 1),
          t('t7', 1),
        ];
        final moves = planRebalance(todos, 3, now: now);
        // Aujourd'hui : 5 tâches pour un rythme de 3 → 2 déplacées.
        expect(moves.map((m) => m.todo.id), ['t4', 't5']);
        // Demain a 1 place, puis après-demain.
        expect(moves[0].to, addDays(today, 1));
        expect(moves[1].to, addDays(today, 2));
        expect(moves.every((m) => m.todo.priority != Priority.high), isTrue);
      },
    );

    test('rien à déplacer si tout est prioritaire ou sous le rythme', () {
      expect(planRebalance([t('t1', 0), t('t2', 0)], 3, now: now), isEmpty);
      expect(
        planRebalance(
          [for (var i = 1; i <= 5; i++) t('t$i', 0, Priority.high)],
          3,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  testWidgets('agenda : sections par jour et alerte de surcharge', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'todos': jsonEncode([
        for (var i = 1; i <= 5; i++)
          Todo(
            id: 'a$i',
            title: 'Aujourd $i',
            dueDate: today,
            priority: i == 1 ? Priority.high : Priority.low,
          ).toJson(),
        Todo(
          id: 'b1',
          title: 'Pour demain',
          dueDate: addDays(today, 1),
        ).toJson(),
        Todo(id: 'c1', title: 'Sans échéance').toJson(),
      ]),
    });
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    // L'alerte apparaît aussi dans la liste.
    expect(find.byKey(const Key('overload-banner')), findsOneWidget);
    expect(find.text("Aujourd'hui est surchargé"), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('5 / 3'), findsOneWidget);

    // Rééquilibrer : 2 tâches basses partent, la haute reste.
    await tester.tap(find.text('Rééquilibrer'));
    await tester.pumpAndSettle();
    expect(find.text('Rééquilibrer ma semaine'), findsOneWidget);
    await tester.tap(find.text('Déplacer 2 tâches'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overload-banner')), findsNothing);
    // Aujourd'hui et demain sont maintenant tous les deux à 3 / 3.
    expect(find.text('3 / 3'), findsNWidgets(2));
    expect(find.text('2 tâches déplacées'), findsOneWidget);

    // Annuler remet tout comme avant.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('5 / 3'), findsOneWidget);
  });

  testWidgets('agenda : choisir un jour pré-remplit l\'échéance', (
    tester,
  ) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-chip-1')));
    await tester.pumpAndSettle();
    expect(find.text('Rien de prévu ce jour-là'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Échéance : Demain'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('editor-title')), 'Sport');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('Rien de prévu ce jour-là'), findsNothing);
  });

  testWidgets('agenda : glisser une tâche sur un autre jour', (tester) async {
    final today = dateOnly(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'todos': jsonEncode([
        Todo(id: 'x', title: 'À déplacer', dueDate: today).toJson(),
      ]),
    });
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('À déplacer')),
    );
    await tester.pump(const Duration(seconds: 1)); // appui long
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('day-chip-2'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('déplacée à'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('todos')!) as List;
    expect(
      DateTime.parse((saved.first as Map)['dueDate'] as String),
      addDays(today, 2),
    );
  });
}
