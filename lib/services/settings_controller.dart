import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pomodoro_config.dart';
import '../theme/app_themes.dart';

/// Préférences d'affichage (thème de couleur, mode clair/sombre),
/// sauvegardées sur l'appareil.
class SettingsController extends ChangeNotifier {
  static const _themeKey = 'themeId';
  static const _modeKey = 'themeMode';
  static const _pomodoroKey = 'pomodoro';

  AppTheme _theme = appThemes.first;
  ThemeMode _mode = ThemeMode.system;
  PomodoroConfig _pomodoro = const PomodoroConfig();

  AppTheme get theme => _theme;
  ThemeMode get mode => _mode;
  PomodoroConfig get pomodoro => _pomodoro;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = themeById(prefs.getString(_themeKey));
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_modeKey),
      orElse: () => ThemeMode.system,
    );
    final rawPomodoro = prefs.getString(_pomodoroKey);
    if (rawPomodoro != null) {
      try {
        _pomodoro = PomodoroConfig.fromJson(
          jsonDecode(rawPomodoro) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    if (theme.id == _theme.id) return;
    _theme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.id);
  }

  Future<void> setPomodoro(PomodoroConfig config) async {
    _pomodoro = config;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pomodoroKey, jsonEncode(config.toJson()));
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}

/// Rend le [SettingsController] accessible à toute l'app.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static SettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
