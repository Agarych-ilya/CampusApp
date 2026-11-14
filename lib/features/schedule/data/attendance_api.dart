import 'dart:convert';

import 'package:http/http.dart' as http;
import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';
import 'schedule_lesson.dart';

class AttendanceIdentity {
  const AttendanceIdentity({
    required this.authenticated, required this.isStarosta,
    required this.registered, this.group, this.displayName,
  });

  final bool authenticated;
  final bool isStarosta;
  final bool registered;
  final String? group;
  final String? displayName;

  factory AttendanceIdentity.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Неверная сессия журнала');
    return AttendanceIdentity(
      authenticated: raw['authenticated'] == true,
      isStarosta: raw['isStarosta'] == true,
      registered: raw['registered'] == true,
      group: raw['group']?.toString(),
      displayName: raw['displayName']?.toString(),
    );
  }
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.ownerKey, required this.displayName,
    required this.status, this.note,
  });

  final String ownerKey;
  final String displayName;
  final String status;
  final String? note;

  factory AttendanceStudent.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Неверная строка журнала');
    final key = raw['ownerKey']?.toString() ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw const FormatException('Неверный идентификатор студента');
    }
    return AttendanceStudent(
      ownerKey: key,
      displayName: raw['displayName']?.toString() ?? 'Студент',
      status: raw['status']?.toString() ?? 'unmarked',
      note: raw['note']?.toString(),
    );
  }
}

class AttendanceLesson {
  const AttendanceLesson({
    required this.id, required this.date, required this.time,
    required this.subject, required this.state,
  });

  final int id;
  final String date;
  final String time;
  final String subject;
  final String state;

  factory AttendanceLesson.fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! num) {
      throw const FormatException('Неверный идентификатор журнала');
    }
    return AttendanceLesson(
      id: (raw['id'] as num).toInt(),
      date: raw['date']?.toString() ?? '',
      time: raw['time']?.toString() ?? '',
      subject: raw['subject']?.toString() ?? '',
      state: raw['state']?.toString() ?? 'open',
    );
  }
}

class AttendanceDetail {
  const AttendanceDetail({
    required this.lesson, required this.students, this.myStatus,
  });

  final AttendanceLesson lesson;
  final List<AttendanceStudent> students;
  final String? myStatus;

  bool get readyToClose => students.isNotEmpty && students.every(
    (student) => const ['present', 'absent', 'excused'].contains(student.status),
  );

  int count(String status) =>
      students.where((student) => student.status == status).length;

  factory AttendanceDetail.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Ошибка загрузки журнала');
    return AttendanceDetail(
      lesson: AttendanceLesson.fromJson(raw),
      myStatus: (raw['mine'] is Map)
          ? (raw['mine'] as Map)['status']?.toString() : null,
      students: (raw['students'] is List)
          ? (raw['students'] as List).map(AttendanceStudent.fromJson).toList()
          : [],
    );
  }
}

class AttendanceApi {
  AttendanceApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Uri get _base => Uri.parse('${ApiConfig.baseUrl}/services/attendance');

  Uri _route(String suffix, [Map<String, String>? query]) => _base.replace(
    path: '${_base.path}$suffix', queryParameters: query,
  );

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  Future<dynamic> _request(String method, String path, {
    Map<String, String>? query, Object? body,
  }) async {
    // Uses the same BARS-authenticated CampusApp session as schedule notes.
    // No second username/password or Telegram login.
    final headers = await ListingsApi.instance.scheduleNotesAuthHeaders(
      write: method != 'GET',
    );
    final uri = _route(path, query);
    late http.Response response;
    final requestHeaders = {
      ...headers, 'Accept': 'application/json',
      if (method != 'GET') 'Content-Type': 'application/json',
    };
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: requestHeaders);
      case 'POST':
        response = await _client.post(uri, headers: requestHeaders,
            body: jsonEncode(body ?? {}));
      case 'PATCH':
        response = await _client.patch(uri, headers: requestHeaders,
            body: jsonEncode(body ?? {}));
      default:
        throw const FormatException('Недопустимый метод');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<AttendanceIdentity> session() async {
    final raw = await _request('GET', '/session');
    return AttendanceIdentity.fromJson(raw);
  }

  Future<void> register(String name) async {
    await _request('POST', '/register', body: {'displayName': name.trim()});
  }

  Future<List<AttendanceLesson>> lessons(DateTime date) async {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final raw = await _request('GET', '/lessons', query: {'date': '$y-$m-$d'});
    if (raw is! List) throw const FormatException('Неверный список занятий');
    return raw.map(AttendanceLesson.fromJson).toList();
  }

  Future<int> open(ScheduleLesson lesson) async {
    final date = lesson.parsedDate;
    if (date == null) throw const FormatException('Дата занятия неизвестна');
    final result = await _request('POST', '/lessons', body: {
      'date': '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'time': lesson.time, 'subject': lesson.subject,
      'type': lesson.type, 'room': lesson.room,
    });
    if (result is! Map || result['id'] is! num) {
      throw const FormatException('Сервер не создал журнал');
    }
    return (result['id'] as num).toInt();
  }

  Future<AttendanceDetail> detail(int id) async =>
      AttendanceDetail.fromJson(await _request('GET', '/lessons/$id'));

  Future<void> checkIn(int id) async {
    await _request('POST', '/lessons/$id/check-in');
  }

  Future<void> decide(int id, AttendanceStudent student, String status) async {
    await _request('PATCH', '/lessons/$id/decision', body: {
      'ownerKey': student.ownerKey, 'status': status,
    });
  }

  Future<void> close(int id, List<AttendanceStudent> students) async {
    await _request('POST', '/lessons/$id/close', body: {
      'acknowledgedStudentKeys': students.map((e) => e.ownerKey).toList(),
    });
  }

  Future<Map<String, dynamic>> barsPreview(int id) async {
    final result = await _request('GET', '/lessons/$id/bars-preview');
    if (result is! Map) throw const FormatException('Нет предпросмотра');
    return Map<String, dynamic>.from(result);
  }

  void dispose() => _client.close();
}
