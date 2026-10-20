import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';

import '/core/config/api_config.dart';

class ScheduleApi {
  static const String _baseUrl = ApiConfig.baseUrl;

  final ScheduleCache _cache = ScheduleCache();

  Future<List<ScheduleLesson>> getWeekSchedule({
    required String group,
    required DateTime selectedDate,
    bool forceRefresh = false,
  }) async {
    final weekStart = _getWeekStart(selectedDate);

    if (!forceRefresh) {
      final cachedLessons = await _cache.getWeekLessons(
        group: group,
        weekStart: weekStart,
      );

      if (cachedLessons != null) {
        return cachedLessons;
      }
    }

    final lessons = await _loadWeekScheduleFromServer(
      group: group,
      weekStart: weekStart,
    );

    await _cache.saveWeekLessons(
      group: group,
      weekStart: weekStart,
      lessons: lessons,
    );

    return lessons;
  }

  Future<List<ScheduleLesson>> _loadWeekScheduleFromServer({
    required String group,
    required DateTime weekStart,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/schedule?group=${Uri.encodeComponent(group)}&date=${_formatDate(weekStart)}',
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось загрузить расписание');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final lessonsJson = data['lessons'];

    if (lessonsJson is! List) {
      return [];
    }

    return lessonsJson
        .map((lesson) => ScheduleLesson.fromJson(lesson))
        .toList();
  }

  DateTime _getWeekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
