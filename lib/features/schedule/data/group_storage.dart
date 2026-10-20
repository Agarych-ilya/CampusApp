import 'package:shared_preferences/shared_preferences.dart';

class GroupStorage {
  static const String _groupKey = 'student_group';

  Future<String?> getGroup() async {
    final prefs = await SharedPreferences.getInstance();

    final group = prefs.getString(_groupKey)?.trim();

    if (group == null || group.isEmpty) {
      return null;
    }

    return group;
  }

  Future<void> saveGroup(String group) async {
    final normalizedGroup = group.trim();

    if (normalizedGroup.isEmpty) {
      throw ArgumentError('Группа не может быть пустой');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_groupKey, normalizedGroup);
  }

  Future<void> clearGroup() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_groupKey);
  }
}
