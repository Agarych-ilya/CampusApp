import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';

/// Take the physical room code from the schedule:
/// "С-401 (Корпус С)" -> "С-401". Online lessons return null.
String? classroomCodeFromLesson(String? roomLabel) {
  final input = roomLabel?.trim() ?? '';
  if (input.isEmpty) return null;
  final match = RegExp(
    r'([A-Za-zА-Яа-яЁё]{1,3})\s*[-–—−]\s*(\d{1,4})(?!\d)',
  ).firstMatch(input);
  if (match == null) return null;
  final building = match.group(1)!.toUpperCase()
      .replaceAll('M', 'М').replaceAll('C', 'С')
      .replaceAll('A', 'А').replaceAll('K', 'К')
      .replaceAll('P', 'Р').replaceAll('T', 'Т')
      .replaceAll('H', 'Н').replaceAll('B', 'В').replaceAll('V', 'В')
      .replaceAll('E', 'Е').replaceAll('O', 'О')
      .replaceAll('X', 'Х');
  return '$building-' + match.group(2)!;
}

const bookableClassrooms = ['М-307', 'В-308'];

bool isBookableClassroom(String? roomLabel) =>
    bookableClassrooms.contains(classroomCodeFromLesson(roomLabel));

int classroomSeatCapacity(String room) =>
    classroomCodeFromLesson(room) == 'В-308' ? 176 : 54;

/// For В-308, row is the tier (1–10), desk is the seat number on a side,
/// seat=1 means the left bank and seat=2 means the right bank.
/// For М-307, these are the original row / desk / seat coordinates.
bool isValidClassroomSeat(String room, int row, int desk, int seat) {
  if (row < 1 || desk < 1 || (seat != 1 && seat != 2)) return false;
  switch (classroomCodeFromLesson(room)) {
    case 'М-307':
      return row <= 3 && desk <= 9;
    case 'В-308':
      return row <= 10 && desk <= (row <= 4 ? 10 : 8);
    default:
      return false;
  }
}

class ClassroomSeat {
  const ClassroomSeat({
    required this.row,
    required this.desk,
    required this.seat,
  });

  final int row;
  final int desk;
  final int seat;

  String get identifier => '$row-$desk-$seat';
  String get label =>
      'Ряд $row, парта $desk, ${seat == 1 ? 'левое' : 'правое'} место';

  String labelForRoom(String room) =>
      classroomCodeFromLesson(room) == 'В-308'
          ? 'Ряд $row, ${seat == 1 ? 'левая' : 'правая'} сторона, место $desk'
          : label;

  @override
  bool operator ==(Object other) =>
      other is ClassroomSeat &&
      row == other.row && desk == other.desk && seat == other.seat;

  @override
  int get hashCode => Object.hash(row, desk, seat);

  factory ClassroomSeat.fromJson(Object? value, {String room = 'М-307'}) {
    if (value is! Map) {
      throw const FormatException('Некорректное место');
    }
    final row = value['row'], desk = value['desk'], seat = value['seat'];
    if (row is! num || desk is! num || seat is! num ||
        row.toInt() != row || desk.toInt() != desk || seat.toInt() != seat ||
        !isValidClassroomSeat(
          room, row.toInt(), desk.toInt(), seat.toInt(),
        )) {
      throw const FormatException('Некорректный номер места');
    }
    return ClassroomSeat(
      row: row.toInt(),
      desk: desk.toInt(),
      seat: seat.toInt(),
    );
  }

  Map<String, int> toJson() =>
      {'row': row, 'desk': desk, 'seat': seat};
}

class ClassroomTimeSlot {
  const ClassroomTimeSlot({required this.id, required this.time});
  final String id;
  final String time;

  factory ClassroomTimeSlot.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Некорректное время');
    return ClassroomTimeSlot(
      id: value['id']?.toString() ?? '',
      time: value['time']?.toString() ?? '',
    );
  }
}

const classroomDemoSlots = [
  ClassroomTimeSlot(id: '1', time: '09:20–10:55'),
  ClassroomTimeSlot(id: '2', time: '11:10–12:45'),
  ClassroomTimeSlot(id: '3', time: '13:45–15:20'),
  ClassroomTimeSlot(id: '4', time: '15:35–17:10'),
  ClassroomTimeSlot(id: '5', time: '17:20–18:55'),
  ClassroomTimeSlot(id: '6', time: '19:05–20:40'),
];

/// Map a timetable lesson to the corresponding test booking interval.
String? classroomSlotForLessonTime(String lessonTime) {
  final lessonTimes = RegExp(r'\d{1,2}:\d{2}')
      .allMatches(lessonTime)
      .map((match) => match.group(0)!)
      .toList();
  if (lessonTimes.length < 2) return null;
  for (final slot in classroomDemoSlots) {
    final slotTimes = RegExp(r'\d{1,2}:\d{2}')
        .allMatches(slot.time)
        .map((match) => match.group(0)!)
        .toList();
    if (slotTimes.length == 2 &&
        lessonTimes[0] == slotTimes[0] &&
        lessonTimes[1] == slotTimes[1]) {
      return slot.id;
    }
  }
  return null;
}

class ClassroomAvailability {
  const ClassroomAvailability({
    required this.room,
    required this.date,
    required this.slot,
    required this.occupied,
    required this.mine,
    required this.slots,
    required this.testMode,
  });

  final String room;
  final String date;
  final String slot;
  final Set<ClassroomSeat> occupied;
  final ClassroomSeat? mine;
  final List<ClassroomTimeSlot> slots;
  final bool testMode;

  int get capacity => classroomSeatCapacity(room);
  int get available => capacity - occupied.length;

  bool isOccupied(ClassroomSeat seat) => occupied.contains(seat);
  bool isMine(ClassroomSeat seat) => mine == seat;

  factory ClassroomAvailability.fromJson(Object? value) {
    if (value is! Map || value['occupied'] is! List) {
      throw const FormatException('Некорректный ответ сервера');
    }
    final room = value['room']?.toString() ?? '';
    if (!isBookableClassroom(room)) {
      throw const FormatException('Неизвестная аудитория в ответе сервера');
    }
    final rawSeats = value['occupied'] as List;
    final occupied = rawSeats
        .map((seat) => ClassroomSeat.fromJson(seat, room: room))
        .toSet();
    final rawMine = value['mine'];
    final mine = rawMine == null
        ? null
        : ClassroomSeat.fromJson(rawMine, room: room);
    final rawSlots = value['slots'];
    return ClassroomAvailability(
      room: room,
      date: value['date']?.toString() ?? '',
      slot: value['slot']?.toString() ?? '',
      occupied: occupied,
      mine: mine,
      slots: rawSlots is List
          ? rawSlots.map(ClassroomTimeSlot.fromJson).toList()
          : classroomDemoSlots,
      testMode: value['testMode'] == true,
    );
  }
}

class ClassroomBookingException implements Exception {
  const ClassroomBookingException(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
  @override
  String toString() => message;
}

/// A verified BARS student can reserve one seat per date/time slot.
/// Unauthenticated users may still view occupancy without student identities.
class ClassroomBookingApi {
  ClassroomBookingApi({
    http.Client? client,
    Future<Map<String, String>> Function()? authorization,
  })  : _client = client ?? http.Client(),
        _authorization = authorization ??
            (() => ListingsApi.instance.studyAuthHeaders());

  final http.Client _client;
  final Future<Map<String, String>> Function() _authorization;

  Uri get _base => Uri.parse(
        '${ApiConfig.baseUrl}/services/room-bookings',
      );

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _message(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final value = data is Map ? data['message'] : null;
      if (value is String) return value;
      if (value is List) return value.join(', ');
    } catch (_) {}
    return 'Ошибка бронирования: HTTP ${response.statusCode}';
  }

  ClassroomAvailability _parse(http.Response response, int success) {
    if (response.statusCode != success) {
      throw ClassroomBookingException(
        _message(response),
        conflict: response.statusCode == 409,
      );
    }
    return ClassroomAvailability.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }

  void _validateRoom(String room) {
    if (!isBookableClassroom(room)) {
      throw const ClassroomBookingException(
        'Пока бронирование доступно только для М-307 и В-308',
      );
    }
  }

  Future<ClassroomAvailability> load({
    required DateTime date,
    required String slot,
    String room = 'М-307',
    bool trySession = true,
  }) async {
    _validateRoom(room);
    if (trySession && !ListingsApi.instance.hasSession) {
      try {
        await ListingsApi.instance.ensureSession();
      } catch (_) {
        // Occupancy is public; only creating/cancelling needs BARS.
      }
    }
    final response = await _client.get(
      _base.replace(queryParameters: {
        'date': dateKey(date),
        'slot': slot,
        'room': room,
      }),
      headers: ListingsApi.instance.studyReadHeaders,
    ).timeout(const Duration(seconds: 17));
    return _checkRoom(_parse(response, 200), room);
  }

  ClassroomAvailability _checkRoom(
    ClassroomAvailability result,
    String requestedRoom,
  ) {
    if (classroomCodeFromLesson(result.room) !=
        classroomCodeFromLesson(requestedRoom)) {
      throw const ClassroomBookingException(
        'Сервер бронирования не поддерживает эту аудиторию. '
        'Обнови backend CampusApp.',
      );
    }
    return result;
  }

  Future<ClassroomAvailability> reserve({
    required DateTime date,
    required String slot,
    required ClassroomSeat seat,
    String room = 'М-307',
  }) async {
    _validateRoom(room);
    final headers = await _authorization();
    final response = await _client.post(
      _base,
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': dateKey(date),
        'slot': slot,
        'room': room,
        ...seat.toJson(),
      }),
    ).timeout(const Duration(seconds: 17));
    return _checkRoom(_parse(response, 201), room);
  }

  Future<ClassroomAvailability> cancel({
    required DateTime date,
    required String slot,
    String room = 'М-307',
  }) async {
    _validateRoom(room);
    final headers = await _authorization();
    final response = await _client.delete(
      _base.replace(queryParameters: {
        'date': dateKey(date),
        'slot': slot,
        'room': room,
      }),
      headers: headers,
    ).timeout(const Duration(seconds: 17));
    return _checkRoom(_parse(response, 200), room);
  }

  void dispose() => _client.close();
}
