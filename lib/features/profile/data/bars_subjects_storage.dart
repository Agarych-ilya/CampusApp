import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bars_subject.dart';

class BarsSubjectsStorage {
  static const String _key = 'bars_subjects';

  Future<void> saveSubjects(List<BarsSubject> subjects) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = subjects.map((subject) => subject.toMap()).toList();

    await prefs.setString(_key, jsonEncode(raw));
  }

  Future<List<BarsSubject>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);

    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      final result = <BarsSubject>[];

      for (final item in decoded) {
        if (item is Map) {
          result.add(BarsSubject.fromMap(Map<String, dynamic>.from(item)));
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearSubjects() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
}
