import 'package:shared_preferences/shared_preferences.dart';

class GroupStorage {
  static const String _groupKey = 'student_group';

  static const String _scheduleGroupKey = 'selected_schedule_group';

  /// A freely selected timetable must not overwrite the BARS profile group.
  Future<String?> getScheduleGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_scheduleGroupKey)?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    return getGroup();
  }

  Future<void> saveScheduleGroup(String group) async {
    final value = group.trim();
    if (value.isEmpty) throw ArgumentError('Группа не может быть пустой');
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_scheduleGroupKey, value);
    if (!saved) throw StateError('Не удалось сохранить выбранную группу');
  }

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
