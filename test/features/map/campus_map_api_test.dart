import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusapp/features/map/data/campus_map_api.dart';

void main() {
  test('public list parses persistent marker and category', () async {
    final api = CampusMapApi(client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/services/map/markers');
      return http.Response(jsonEncode([
        {
          'id':'seed-4', 'name':'Библиотека МЭИ',
          'description':'Читальный зал', 'address':'Москва',
          'kind':'library', 'latitude':55.756, 'longitude':37.7106,
        },
      ]), 200);
    }));
    addTearDown(api.dispose);
    final list = await api.list();
    expect(list, hasLength(1));
    expect(list.first.name, 'Библиотека МЭИ');
    expect(list.first.kind, 'library');
    expect(list.first.point.latitude, 55.756);
  });

  test('invalid server coordinates cannot become rendered pins', () {
    expect(() => CampusMapMarker.fromJson({
      'id':'bad', 'latitude': 999, 'longitude':37,
    }), throwsFormatException);
  });

  test('map draft includes editable name, kind, and precise position', () {
    const draft = CampusMapDraft(
      name: ' Корпус М ', description:'Учебный',
      address:'Красноказарменная ул.',
      kind:'building', latitude:55.7562, longitude:37.7102,
    );
    expect(draft.toJson(), containsPair('name','Корпус М'));
    expect(draft.toJson(), containsPair('latitude',55.7562));
    expect(campusMarkerKinds.keys, containsAll(
      ['building','library','sports','culture','service','other'],
    ));
  });
}
