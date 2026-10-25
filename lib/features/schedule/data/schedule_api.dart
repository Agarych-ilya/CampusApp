import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';
import '/core/config/api_config.dart';

class ScheduleLoadException implements Exception {
  const ScheduleLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleApi {
  final ScheduleCache _cache = ScheduleCache();

  /// True if a server error forced us to show previously saved lessons.
  bool showingOfflineCopy = false;

  Future<List<ScheduleLesson>> getWeekSchedule({
    required String group,
    required DateTime selectedDate,
    bool forceRefresh = false,
  }) async {
    final weekStart = _getWeekStart(selectedDate);
    showingOfflineCopy = false;

    if (!forceRefresh) {
      final cachedLessons = await _cache.getWeekLessons(
        group: group,
        weekStart: weekStart,
      );

      if (cachedLessons != null) return cachedLessons;
    }

    try {
      final lessons = await _loadWeekScheduleFromServer(
        group: group,
        weekStart: weekStart,
      );

      // The network response is already valid even if disk cache is full.
      try {
        await _cache.saveWeekLessons(
          group: group,
          weekStart: weekStart,
          lessons: lessons,
        );
      } catch (_) {
        // Continue showing live data without a local cache.
      }

      return lessons;
    } catch (_) {
      final cachedLessons = await _cache.getWeekLessons(
        group: group,
        weekStart: weekStart,
        allowExpired: true,
      );

      if (cachedLessons != null && cachedLessons.isNotEmpty) {
        showingOfflineCopy = true;
        return cachedLessons;
      }

      rethrow;
    }
  }

  Future<List<ScheduleLesson>> _loadWeekScheduleFromServer({
    required String group,
    required DateTime weekStart,
  }) async {
    // The address 10.0.2.2 reaches the development PC from Android Emulator.
    // On a real phone, the configured LAN IP (or dart-define URL) is used.
    // Probe /health first: a dead old IP should not stall a long MPEI request.
    for (final baseUrl in ApiConfig.scheduleBaseUrls) {
      try {
        final probe = await http
            .get(Uri.parse(baseUrl + '/health'))
            .timeout(const Duration(seconds: 3));

        if (probe.statusCode != 200) continue;
      } catch (_) {
        continue;
      }

      final uri = Uri.parse(baseUrl + '/schedule').replace(
        queryParameters: {
          'group': group,
          'date': _formatDate(weekStart),
        },
      );

      http.Response response;
      try {
        response = await http.get(uri).timeout(
          const Duration(seconds: 70),
        );
      } on TimeoutException {
        throw const ScheduleLoadException(
          'Сервер слишком долго загружает расписание МЭИ. '
          'Повтори запрос немного позже.',
        );
      } catch (_) {
        throw const ScheduleLoadException(
          'Связь с бэкендом прервалась во время загрузки расписания.',
        );
      }

      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          throw ScheduleLoadException(
            'Группа «' + group + '» не найдена в расписании МЭИ.',
          );
        }

        if (response.statusCode == 503 || response.statusCode == 502) {
          throw const ScheduleLoadException(
            'Сайт расписания МЭИ временно недоступен. '
            'Попробуй обновить расписание позже.',
          );
        }

        throw ScheduleLoadException(
          'Ошибка сервера расписания: HTTP ' +
              response.statusCode.toString() + '.',
        );
      }

      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data is! Map<String, dynamic> || data['lessons'] is! List) {
          throw const FormatException('Unexpected schedule JSON');
        }

        return (data['lessons'] as List)
            .map((item) => ScheduleLesson.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
      } catch (_) {
        throw const ScheduleLoadException(
          'Сервер вернул некорректные данные расписания.',
        );
      }
    }

    throw const ScheduleLoadException(
      'Нет связи с бэкендом CampusApp. '
      'Запусти сервер командой npm run start:dev на порту 8000. '
      'Для эмулятора используется 10.0.2.2; на телефоне '
      'проверь IP компьютера в настройках API.',
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
