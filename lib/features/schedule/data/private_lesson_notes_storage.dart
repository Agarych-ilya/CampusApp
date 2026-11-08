import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'schedule_lesson.dart';

/// Notes saved on this device only. Never sent to Campus-backend.
class PrivateLessonNotesStorage {
  static const _prefix = 'campus_schedule_private_note_v1:';

  String key({
    required String group,
    required ScheduleLesson lesson,
  }) {
    final date = lesson.parsedDate;
    if (date == null) throw const FormatException('Неизвестная дата пары');
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final value = [group.trim().toUpperCase(), iso,
      lesson.time.trim(), lesson.subject.trim()].join('|');
    return _prefix + base64Url.encode(utf8.encode(value));
  }

  Future<String> load({required String group, required ScheduleLesson lesson}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key(group: group, lesson: lesson)) ?? '';
  }

  Future<void> save({
    required String group,
    required ScheduleLesson lesson,
    required String content,
  }) async {
    if (content.length > 10000) {
      throw const FormatException('Личная заметка не должна превышать 10 000 символов');
    }
    final prefs = await SharedPreferences.getInstance();
    final storageKey = key(group: group, lesson: lesson);
    final success = content.trim().isEmpty
        ? await prefs.remove(storageKey)
        : await prefs.setString(storageKey, content);
    if (!success) throw const FormatException('Не удалось сохранить заметку');
  }
}
