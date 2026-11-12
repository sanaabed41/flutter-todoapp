import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../models/todo.dart';

/// Sauvegarde les tâches localement sur l'appareil.
class TodoStorage {
  static const _key = 'todos';
  static const _sortKey = 'sortMode';
  static const _progressKey = 'progress';

  Future<List<Todo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(todos.map((t) => t.toJson()).toList()),
    );
  }

  Future<Progress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return Progress();
    try {
      return Progress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Progress();
    }
  }

  Future<void> saveProgress(Progress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, jsonEncode(progress.toJson()));
  }

  Future<String?> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortKey);
  }

  Future<void> saveSortMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, mode);
  }
}
