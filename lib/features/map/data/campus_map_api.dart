import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '/core/config/api_config.dart';
import '/features/services/data/community_admin_api.dart';

const campusMarkerKinds = <String, String>{
  'building': 'Корпус', 'library': 'Библиотека',
  'sports': 'Спорт', 'culture': 'Культура',
  'service': 'Сервис', 'other': 'Другое',
};

class CampusMapMarker {
  const CampusMapMarker({
    required this.id, required this.name, required this.description,
    required this.address, required this.kind, required this.latitude,
    required this.longitude,
  });
  final String id, name, description, address, kind;
  final double latitude, longitude;
  LatLng get point => LatLng(latitude, longitude);

  factory CampusMapMarker.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Неверный формат метки');
    final lat = raw['latitude'], lon = raw['longitude'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      throw const FormatException('Неверные координаты');
    }
    final kind = raw['kind']?.toString() ?? 'other';
    return CampusMapMarker(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      address: raw['address']?.toString() ?? '',
      kind: campusMarkerKinds.containsKey(kind) ? kind : 'other',
      latitude: lat.toDouble(), longitude: lon.toDouble(),
    );
  }
}

class CampusMapDraft {
  const CampusMapDraft({
    required this.name, required this.description, required this.address,
    required this.kind, required this.latitude, required this.longitude,
  });
  final String name, description, address, kind;
  final double latitude, longitude;

  factory CampusMapDraft.fromMarker(CampusMapMarker marker) =>
      CampusMapDraft(name: marker.name, description: marker.description,
        address: marker.address, kind: marker.kind,
        latitude: marker.latitude, longitude: marker.longitude);

  Map<String, dynamic> toJson() => {
    'name': name.trim(), 'description': description.trim(),
    'address': address.trim(), 'kind': kind,
    'latitude': latitude, 'longitude': longitude,
  };
}

class CampusMapApi {
  CampusMapApi({http.Client? client, CommunityAdminApi? admin})
      : _client = client ?? http.Client(), _ownsClient = client == null,
        _admin = admin ?? CommunityAdminApi.instance;
  final http.Client _client;
  final bool _ownsClient;
  final CommunityAdminApi _admin;

  Future<List<CampusMapMarker>> list() async {
    final response = await _client.get(
      Uri.parse(ApiConfig.baseUrl + '/services/map/markers'),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить карту: HTTP ' +
          response.statusCode.toString());
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const FormatException('Неверный ответ карты');
    return data.map(CampusMapMarker.fromJson).toList();
  }

  Future<CampusMapMarker> create(CampusMapDraft draft) async {
    final json = await _admin.mapMutation('POST', '', body: draft.toJson());
    return CampusMapMarker.fromJson(json);
  }

  Future<CampusMapMarker> update(String id, CampusMapDraft draft) async {
    final json = await _admin.mapMutation(
      'PATCH', '/' + Uri.encodeComponent(id), body: draft.toJson());
    return CampusMapMarker.fromJson(json);
  }

  Future<void> delete(String id) async {
    await _admin.mapMutation('DELETE', '/' + Uri.encodeComponent(id));
  }

  void dispose() { if (_ownsClient) _client.close(); }
}
