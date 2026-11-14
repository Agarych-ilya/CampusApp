import 'dart:convert';

import 'package:http/http.dart' as http;
import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';
import 'schedule_lesson.dart';

class GroupLessonNote {
  const GroupLessonNote({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.isMine,
  });

  final int id;
  final String content;
  final String author;
  final DateTime createdAt;
  final bool isMine;

  factory GroupLessonNote.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Некорректная заметка');
    final id = value['id'];
    return GroupLessonNote(
      id: id is num ? id.toInt() : int.parse('$id'),
      content: value['content']?.toString() ?? '',
      author: value['author']?.toString() ?? 'Студент',
      isMine: value['isMine'] == true,
      createdAt: DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class GroupLessonNotesApi {
  GroupLessonNotesApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri get _uri => Uri.parse('${ApiConfig.baseUrl}/services/schedule-notes');

  Map<String, String> _params(String group, ScheduleLesson lesson) {
    final date = lesson.parsedDate;
    if (date == null) throw const FormatException('Дата занятия неизвестна');
    return {
      'group': group.trim(),
      'date': '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'time': lesson.time,
      'subject': lesson.subject,
    };
  }

  String _error(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'Ошибка сервера: HTTP ${response.statusCode}';
  }

  Future<List<GroupLessonNote>> list(String group, ScheduleLesson lesson) async {
    // Group notes are private to the server-verified BARS group.
    final headers = await ListingsApi.instance.scheduleNotesAuthHeaders();
    final uri = _uri.replace(queryParameters: _params(group, lesson));
    final response = await _client.get(
      uri,
      headers: headers,
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception(_error(response));
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const FormatException('Ошибка списка заметок');
    return data.map(GroupLessonNote.fromJson).toList();
  }

  Future<GroupLessonNote> create(
    String group,
    ScheduleLesson lesson,
    String content,
  ) async {
    final headers = await ListingsApi.instance.scheduleNotesAuthHeaders(write: true);
    final response = await _client.post(
      _uri,
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        ..._params(group, lesson),
        'content': content,
      }),
    ).timeout(const Duration(seconds: 18));
    if (response.statusCode != 201) throw Exception(_error(response));
    return GroupLessonNote.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> delete(int id) async {
    final headers = await ListingsApi.instance.scheduleNotesAuthHeaders(write: true);
    final response = await _client.delete(
      _uri.replace(path: '${_uri.path}/$id'),
      headers: headers,
    ).timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) throw Exception(_error(response));
  }

  void dispose() => _client.close();
}
