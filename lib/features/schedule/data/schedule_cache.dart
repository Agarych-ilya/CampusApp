import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'schedule_lesson.dart';

class ScheduleCache {
  static const Duration cacheLifetime = Duration(hours: 12);

  // Новая версия кэша.
  // Старый неправильный кэш больше не будет использоваться.
  static const String _cacheVersion = 'v2';

  String _getWeekLessonsKey({
    required String group,
    required DateTime weekStart,
  }) {
    return '$_cacheVersion/schedule_week_${group}_${_formatDate(weekStart)}';
  }

  String _getWeekSavedAtKey({
    required String group,
    required DateTime weekStart,
  }) {
    return '$_cacheVersion/schedule_week_saved_at_${group}_${_formatDate(weekStart)}';
  }

  Future<List<ScheduleLesson>?> getWeekLessons({
    required String group,
    required DateTime weekStart,
    bool allowExpired = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final lessonsKey = _getWeekLessonsKey(group: group, weekStart: weekStart);

    final savedAtKey = _getWeekSavedAtKey(group: group, weekStart: weekStart);

    final lessonsString = prefs.getString(lessonsKey);
    final savedAtString = prefs.getString(savedAtKey);

    if (lessonsString == null || savedAtString == null) {
      return null;
    }

    final savedAt = DateTime.tryParse(savedAtString);

    if (savedAt == null) {
      return null;
    }

    final isExpired = DateTime.now().difference(savedAt) > cacheLifetime;

    if (isExpired && !allowExpired) {
      return null;
    }

    final decodedData = jsonDecode(lessonsString);

    if (decodedData is! List) {
      return null;
    }

    return decodedData
        .map((lesson) => ScheduleLesson.fromJson(lesson))
        .toList();
  }

  Future<void> saveWeekLessons({
    required String group,
    required DateTime weekStart,
    required List<ScheduleLesson> lessons,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final lessonsKey = _getWeekLessonsKey(group: group, weekStart: weekStart);

    final savedAtKey = _getWeekSavedAtKey(group: group, weekStart: weekStart);

    final lessonsJson = lessons.map((lesson) => lesson.toJson()).toList();

    await prefs.setString(lessonsKey, jsonEncode(lessonsJson));

    await prefs.setString(savedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> clearWeekLessons({
    required String group,
    required DateTime weekStart,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_getWeekLessonsKey(group: group, weekStart: weekStart));

    await prefs.remove(_getWeekSavedAtKey(group: group, weekStart: weekStart));
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
