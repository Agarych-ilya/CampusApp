import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'student_profile.dart';

class StudentProfileStorage {
  static const String _profileKey = 'student_profile';

  Future<void> saveProfile(StudentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    final json = jsonEncode(profile.toMap());

    await prefs.setString(_profileKey, json);
  }

  Future<StudentProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final json = prefs.getString(_profileKey);

    if (json == null || json.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(json);

      if (decoded is Map) {
        return StudentProfile.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}

    return null;
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_profileKey);
  }
}
