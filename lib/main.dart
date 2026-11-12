import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/todo_list_screen.dart';
import 'services/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Charger le thème avant le premier affichage évite un flash de couleur.
  final settings = SettingsController();
  await settings.load();
  runApp(TodoApp(settings: settings));
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key, this.settings});

  final SettingsController? settings;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late final SettingsController _settings =
      widget.settings ?? (SettingsController()..load());

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp(
          title: 'Mes tâches',
          debugShowCheckedModeBanner: false,
          // Calendrier, boutons système, etc. en français.
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _settings.theme.data(Brightness.light),
          darkTheme: _settings.theme.data(Brightness.dark),
          themeMode: _settings.mode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          home: const TodoListScreen(),
        ),
      ),
    );
  }
}
