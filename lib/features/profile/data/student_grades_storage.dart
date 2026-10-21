import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'student_grade.dart';

class StudentGradesStorage {
  static const String _key = 'student_grades';

  Future<void> saveGrades(List<StudentGrade> grades) async {
    final prefs = await SharedPreferences.getInstance();

    final json = jsonEncode(grades.map((grade) => grade.toMap()).toList());

    await prefs.setString(_key, json);
  }

  Future<List<StudentGrade>> getGrades() async {
    final prefs = await SharedPreferences.getInstance();

    final json = prefs.getString(_key);

    if (json == null || json.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(json);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => StudentGrade.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearGrades() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
}
