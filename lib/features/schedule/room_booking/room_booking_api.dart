import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';

/// Coordinates are scoped by classroom, lesson date and timetable slot.
/// M-307: row 1..3, desk 1..9, seat 1..2.
/// V-308: row 1..10, desk 1=left / 2=right, seat from aisle outward.
class RoomSeat {
  const RoomSeat(this.row, this.desk, this.seat, {this.mine = false});

  final int row;
  final int desk;
  final int seat;
  final bool mine;

  String get key => '$row:$desk:$seat';

  factory RoomSeat.fromJson(Map<String, dynamic> json) => RoomSeat(
        (json['row'] as num).toInt(),
        (json['desk'] as num).toInt(),
        (json['seat'] as num).toInt(),
        mine: json['mine'] == true,
      );
}

class RoomAvailability {
  const RoomAvailability({
    required this.capacity,
    required this.available,
    required this.occupied,
    required this.mine,
  });

  final int capacity;
  final int available;
  final List<RoomSeat> occupied;
  final RoomSeat? mine;

  factory RoomAvailability.fromJson(Map<String, dynamic> json) {
    final raw = json['occupied'] as List<dynamic>? ?? const [];
    final occupied = raw.map((item) =>
        RoomSeat.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    final mineJson = json['mine'];
    return RoomAvailability(
      capacity: (json['capacity'] as num).toInt(),
      available: (json['available'] as num).toInt(),
      occupied: occupied,
      mine: mineJson is Map
          ? RoomSeat.fromJson(Map<String, dynamic>.from(mineJson))
          : null,
    );
  }
}

class RoomBookingApi {
  const RoomBookingApi();

  static String? supportedRoom(String raw) {
    final input = raw.toUpperCase().replaceAll('–', '-')
        .replaceAll('—', '-').replaceAll('−', '-');
    final match = RegExp(r'(^|[^A-ZА-ЯЁ0-9])([МMВB])\s*-\s*(307|308)(?![0-9])')
        .firstMatch(input);
    if (match == null) return null;
    final building = match.group(2)!;
    final number = match.group(3)!;
    if ((building == 'М' || building == 'M') && number == '307') {
      return 'М-307';
    }
    if ((building == 'В' || building == 'B') && number == '308') {
      return 'В-308';
    }
    return null;
  }

  static String? slotFromTime(String time) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;
    final start = "${match.group(1)!.padLeft(2, '0')}:${match.group(2)}";
    const slots = <String, String>{
      '09:20': '1',
      '11:10': '2',
      '13:45': '3',
      '15:35': '4',
      '17:20': '5',
      '19:05': '6',
    };
    return slots[start];
  }

  static String dateIso(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Uri _uri(String room, String date, String slot) =>
      Uri.parse('${ApiConfig.baseUrl}/services/room-bookings')
          .replace(queryParameters: {
        'room': room,
        'date': date,
        'slot': slot,
      });

  Exception _error(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        final message = body['message'];
        if (message is String) return Exception(message);
        if (message is List) return Exception(message.join(', '));
      }
    } catch (_) {}
    return Exception('Не удалось обновить бронь (HTTP ${response.statusCode})');
  }

  RoomAvailability _parse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw const FormatException('Неверный ответ сервера');
    return RoomAvailability.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RoomAvailability> load({
    required String room,
    required String date,
    required String slot,
  }) async {
    // A BARS session already verified in CampusApp is reused; no second login
    // form is shown. Anonymous GET still provides the occupied seats.
    try {
      await ListingsApi.instance.ensureSession();
    } catch (_) {}
    final response = await http.get(
      _uri(room, date, slot),
      headers: ListingsApi.instance.studyReadHeaders,
    ).timeout(const Duration(seconds: 20));
    return _parse(response);
  }

  Future<RoomAvailability> reserve({
    required String room,
    required String date,
    required String slot,
    required RoomSeat seat,
  }) async {
    final headers = await ListingsApi.instance.studyAuthHeaders();
    final response = await http.post(
      _uri(room, date, slot),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'room': room,
        'date': date,
        'slot': slot,
        'row': seat.row,
        'desk': seat.desk,
        'seat': seat.seat,
      }),
    ).timeout(const Duration(seconds: 20));
    return _parse(response);
  }

  Future<RoomAvailability> cancel({
    required String room,
    required String date,
    required String slot,
  }) async {
    final headers = await ListingsApi.instance.studyAuthHeaders();
    final response = await http.delete(
      _uri(room, date, slot),
      headers: headers,
    ).timeout(const Duration(seconds: 20));
    return _parse(response);
  }
}
