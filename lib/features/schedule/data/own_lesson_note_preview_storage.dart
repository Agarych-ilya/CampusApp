import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'private_lesson_notes_storage.dart';
import 'schedule_lesson.dart';

/// An on-device preview of notes the student actually authored.
/// Shared notes are still stored and protected on the server; this preview
/// is only a local display cache, never an authorization source.
class OwnLessonNotePreview {
  const OwnLessonNotePreview({
    this.personal = '',
    this.published = '',
  });

  final String personal;
  final String published;

  bool get isEmpty => personal.trim().isEmpty && published.trim().isEmpty;
}

class OwnLessonNotePreviewStorage {
  OwnLessonNotePreviewStorage({PrivateLessonNotesStorage? privateStorage})
      : _privateStorage = privateStorage ?? PrivateLessonNotesStorage();

  static const _sharedPrefix = 'campus_schedule_shared_preview_v1:';
  final PrivateLessonNotesStorage _privateStorage;

  String _groupKey(String group, ScheduleLesson lesson) {
    final noteKey = _privateStorage.key(group: group, lesson: lesson);
    return _sharedPrefix + base64Url.encode(utf8.encode(noteKey));
  }

  Future<OwnLessonNotePreview> load({
    required String group,
    required ScheduleLesson lesson,
  }) async {
    final personal = await _privateStorage.load(group: group, lesson: lesson);
    final prefs = await SharedPreferences.getInstance();
    final published = prefs.getString(_groupKey(group, lesson)) ?? '';
    return OwnLessonNotePreview(
      personal: personal.trim(),
      published: published.trim(),
    );
  }

  Future<void> savePublished({
    required String group,
    required ScheduleLesson lesson,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _groupKey(group, lesson);
    final saved = content.trim().isEmpty
        ? await prefs.remove(key)
        : await prefs.setString(key, content.trim());
    if (!saved) throw StateError('Не удалось обновить предпросмотр заметки');
  }
}
