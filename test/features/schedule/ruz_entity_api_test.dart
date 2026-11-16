import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusapp/features/schedule/data/ruz_entity_api.dart';

void main() {
  test('RUZ room search uses validated read-only endpoint', () async {
    final api = RuzEntityApi(client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/schedule/ruz/search');
      expect(request.url.queryParameters['type'], 'auditorium');
      expect(request.url.queryParameters['q'], 'М-307');
      return http.Response(jsonEncode([
        {
          'id': 1307,
          'label': 'М-307',
          'description': 'Корпус М',
          'type': 'auditorium',
        },
      ]), 200);
    }));
    addTearDown(api.dispose);
    final results = await api.search('auditorium', 'М-307');
    expect(results, hasLength(1));
    expect(results.first.label, 'М-307');
  });

  test('teacher schedule maps MPEI dates and does not offer booking', () async {
    final api = RuzEntityApi(client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/schedule/ruz/lessons');
      expect(request.url.queryParameters['type'], 'person');
      expect(request.url.queryParameters['id'], '123');
      return http.Response(jsonEncode([
        {
          'date': '2026.11.16',
          'time': '10:15–11:50',
          'subject': 'ТАУ',
          'type': 'Практическое занятие',
          'room': 'М-307',
          'teacher': 'Смирнов С.С.',
          'group': 'А-03-23',
        },
      ]), 200);
    }));
    addTearDown(api.dispose);
    final lessons = await api.schedule(
      const RuzEntity(
        id: 123, label: 'Смирнов С.С.',
        description: 'МЭИ', type: 'person',
      ),
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 23),
    );
    expect(lessons.single.room, 'М-307');
    expect(lessons.single.group, 'А-03-23');
  });

  test('invalid entity IDs and wrong server data fail closed', () {
    expect(() => RuzEntity.fromJson({
      'id': 0, 'label': 'Некорректно',
    }), throwsFormatException);
  });
}
