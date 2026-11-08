import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusapp/features/services/booking/data/classroom_booking_api.dart';
import 'package:campusapp/features/services/booking/view/classroom_booking_screen.dart';
import 'package:campusapp/features/services/booking/view/classroom_seat_map.dart';
import 'package:campusapp/features/services/booking/view/amphitheater_seat_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const selectedSeat = ClassroomSeat(row: 3, desk: 9, seat: 2);
  const occupiedSeat = ClassroomSeat(row: 1, desk: 1, seat: 1);

  test('M-307 has exactly 54 possible seats and unique desk positions', () {
    final seats = <ClassroomSeat>{};
    for (var row = 1; row <= 3; row++) {
      for (var desk = 1; desk <= 9; desk++) {
        for (var seat = 1; seat <= 2; seat++) {
          seats.add(ClassroomSeat(row: row, desk: desk, seat: seat));
        }
      }
    }
    expect(seats, hasLength(54));
    expect(seats.contains(selectedSeat), isTrue);
    expect(selectedSeat.label, contains('правое'));
  });

  test('timetable time automatically selects a matching booking slot', () {
    expect(classroomSlotForLessonTime('13:45 - 15:20'), '3');
    expect(classroomSlotForLessonTime('09:20 – 10:55'), '1');
    expect(classroomSlotForLessonTime('15:35 – 17:10'), '4');
    expect(classroomSlotForLessonTime('08:00 – 09:00'), isNull);
  });

  test('room labels from lesson map to normalized physical classrooms', () {
    expect(classroomCodeFromLesson('С-401 (Корпус С)'), 'С-401');
    expect(classroomCodeFromLesson('C-401 (Корпус C)'), 'С-401');
    expect(classroomCodeFromLesson('М-307'), 'М-307');
    expect(classroomCodeFromLesson('M-307'), 'М-307');
    expect(classroomCodeFromLesson('В-308 (Корпус В)'), 'В-308');
    expect(classroomCodeFromLesson('V-308'), 'В-308');
    expect(isBookableClassroom('В-308 (Корпус В)'), isTrue);
    expect(isBookableClassroom('С-401'), isFalse);
    expect(classroomCodeFromLesson('ЭО и ДОТ (-)'), isNull);
  });

  test('В-308 has 176 positions: four red and six blue rows per bank', () {
    final seats = <ClassroomSeat>{};
    for (var row = 1; row <= 10; row++) {
      final limit = row <= 4 ? 10 : 8;
      for (var side = 1; side <= 2; side++) {
        for (var number = 1; number <= limit; number++) {
          expect(isValidClassroomSeat('В-308', row, number, side), isTrue);
          seats.add(ClassroomSeat(row: row, desk: number, seat: side));
        }
      }
    }
    expect(seats, hasLength(176));
    expect(classroomSeatCapacity('В-308'), 176);
    expect(classroomSeatCapacity('М-307'), 54);
    expect(isValidClassroomSeat('В-308', 4, 10, 2), isTrue);
    expect(isValidClassroomSeat('В-308', 5, 9, 2), isFalse);
    expect(isValidClassroomSeat('В-308', 11, 1, 1), isFalse);
    expect(
      const ClassroomSeat(row: 5, desk: 8, seat: 2).labelForRoom('В-308'),
      'Ряд 5, правая сторона, место 8',
    );
  });

  test('В-308 availability parses both sides and its 176-seat capacity', () {
    final data = ClassroomAvailability.fromJson({
      'room': 'В-308', 'date': '2026-11-10', 'slot': '2',
      'testMode': true,
      'occupied': [
        {'row': 4, 'desk': 10, 'seat': 1, 'mine': false},
        {'row': 9, 'desk': 8, 'seat': 2, 'mine': true},
      ],
      'mine': {'row': 9, 'desk': 8, 'seat': 2, 'mine': true},
    });
    expect(data.capacity, 176);
    expect(data.available, 174);
    expect(data.mine, const ClassroomSeat(row: 9, desk: 8, seat: 2));
    expect(() => ClassroomSeat.fromJson(
      {'row': 5, 'desk': 9, 'seat': 1}, room: 'В-308',
    ), throwsFormatException);
  });

  testWidgets('В-308 map has 176 clickable seats with a central aisle',
      (tester) async {
    ClassroomSeat? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AmphitheaterSeatMap(
            occupied: const {ClassroomSeat(row: 1, desk: 1, seat: 1)},
            mine: null,
            selected: null,
            onSelected: (seat) => picked = seat,
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('amphitheater-red-zone')), findsOneWidget);
    expect(find.byKey(const ValueKey('amphitheater-blue-zone')), findsOneWidget);
    expect(find.byKey(const ValueKey('amphitheater-row-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-4-10-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-4-10-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-5-8-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-5-9-2')), findsNothing);
    expect(find.byType(InkWell), findsAtLeastNWidgets(176));
    final unavailable = find.byKey(const ValueKey('room-seat-1-1-1'));
    await tester.ensureVisible(unavailable);
    await tester.tap(unavailable);
    expect(picked, isNull);
    final blue = find.byKey(const ValueKey('room-seat-5-8-2'));
    await tester.ensureVisible(blue);
    await tester.tap(blue);
    expect(picked, const ClassroomSeat(row: 5, desk: 8, seat: 2));
  });

  test('availability identifies full seats, reserved seats and mine', () {
    final data = ClassroomAvailability.fromJson({
      'room': 'М-307',
      'date': '2026-11-10',
      'slot': '1',
      'testMode': true,
      'occupied': [
        {'row': 1, 'desk': 1, 'seat': 1, 'mine': false},
        {'row': 3, 'desk': 9, 'seat': 2, 'mine': true},
      ],
      'mine': {'row': 3, 'desk': 9, 'seat': 2, 'mine': true},
      'slots': [{'id': '1', 'time': '09:20–10:55'}],
    });
    expect(data.capacity, 54);
    expect(data.available, 52);
    expect(data.isOccupied(occupiedSeat), isTrue);
    expect(data.isMine(selectedSeat), isTrue);
    expect(data.isOccupied(const ClassroomSeat(row: 1, desk: 1, seat: 2)),
        isFalse);
  });

  testWidgets('seat map has 3 rows x 9 desks x 2 seats', (tester) async {
    ClassroomSeat? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClassroomSeatMap(
          occupied: {occupiedSeat},
          mine: null,
          selected: null,
          onSelected: (seat) => tapped = seat,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('room-seat-3-9-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-1-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-2-5-1')), findsOneWidget);
    expect(find.byType(InkWell), findsAtLeastNWidgets(54));
    // Each physical row is a vertical column of nine desks.
    final row1Desk1 = tester.getTopLeft(
      find.byKey(const ValueKey('room-seat-1-1-1')),
    );
    final row1Desk9 = tester.getTopLeft(
      find.byKey(const ValueKey('room-seat-1-9-1')),
    );
    final row2Desk1 = tester.getTopLeft(
      find.byKey(const ValueKey('room-seat-2-1-1')),
    );
    expect(row1Desk9.dy, greaterThan(row1Desk1.dy));
    expect(row2Desk1.dx, greaterThan(row1Desk1.dx));
    expect((row1Desk9.dx - row1Desk1.dx).abs(), lessThan(1));
    expect(find.byKey(const ValueKey('room-vertical-rows')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-seat-1-1-1')));
    expect(tapped, isNull); // occupied seats cannot be selected
    await tester.tap(find.byKey(const ValueKey('room-seat-1-1-2')));
    expect(tapped, const ClassroomSeat(row: 1, desk: 1, seat: 2));
  });

  test('API uses the selected seat, date and slot and handles conflicts',
      () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      if (request.method == 'POST') {
        expect(request.headers['x-listing-csrf'], 'test-csrf');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['slot'], '2');
        expect(body['row'], 3);
        expect(body['desk'], 9);
        expect(body['seat'], 2);
        return http.Response(
          '{"message":"Место уже занято"}',
          409,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({
        'room': 'М-307',
        'date': '2026-11-10',
        'slot': '2',
        'testMode': true,
        'occupied': [],
        'mine': null,
        'slots': [],
      }), 200);
    });
    final api = ClassroomBookingApi(
      client: client,
      authorization: () async => {'X-Listing-CSRF': 'test-csrf'},
    );
    final status = await api.load(
      date: DateTime(2026, 11, 10),
      slot: '2',
      trySession: false,
    );
    expect(status.available, 54);
    await expectLater(
      () => api.reserve(
        date: DateTime(2026, 11, 10),
        slot: '2',
        seat: selectedSeat,
      ),
      throwsA(isA<ClassroomBookingException>()
          .having((e) => e.conflict, 'conflict', isTrue)),
    );
    expect(calls.last.method, 'POST');
    expect((jsonDecode(calls.last.body) as Map)['room'], 'М-307');
    api.dispose();
  });

  test('API rejects unsupported classrooms before any network request',
      () async {
    var calls = 0;
    final api = ClassroomBookingApi(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 500);
      }),
      authorization: () async => {'X-Listing-CSRF': 'test-csrf'},
    );
    final date = DateTime(2026, 11, 10);
    final expected = throwsA(isA<ClassroomBookingException>());
    await expectLater(
      () => api.load(
        date: date, slot: '2', room: 'С-401', trySession: false,
      ), expected,
    );
    await expectLater(
      () => api.reserve(
        date: date, slot: '2', room: 'С-401',
        seat: const ClassroomSeat(row: 1, desk: 1, seat: 2),
      ), expected,
    );
    await expectLater(
      () => api.cancel(date: date, slot: '2', room: 'С-401'),
      expected,
    );
    expect(calls, 0);
    api.dispose();
  });

  test('В-308 booking and cancellation use its own classroom identifier',
      () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      final row = request.method == 'POST'
          ? jsonDecode(request.body) as Map<String, dynamic>
          : null;
      if (row != null) {
        expect(row['room'], 'В-308');
        expect(row['row'], 5);
        expect(row['desk'], 8);
        expect(row['seat'], 2);
      } else {
        expect(request.url.queryParameters['room'], 'В-308');
      }
      return http.Response(
        jsonEncode({
          'room': 'В-308',
          'date': '2026-11-10',
          'slot': '3',
          'testMode': true,
          'occupied': request.method == 'POST'
              ? [
                  {'row': 5, 'desk': 8, 'seat': 2, 'mine': true},
                ]
              : [],
          'mine': request.method == 'POST'
              ? {'row': 5, 'desk': 8, 'seat': 2, 'mine': true}
              : null,
        }),
        request.method == 'POST' ? 201 : 200,
      );
    });
    final api = ClassroomBookingApi(
      client: client,
      authorization: () async => {'X-Listing-CSRF': 'test'},
    );
    final date = DateTime(2026, 11, 10);
    final empty = await api.load(
      date: date, slot: '3', room: 'В-308', trySession: false,
    );
    expect(empty.available, 176);
    final mine = await api.reserve(
      date: date,
      slot: '3',
      room: 'В-308',
      seat: const ClassroomSeat(row: 5, desk: 8, seat: 2),
    );
    expect(mine.available, 175);
    expect(mine.mine?.labelForRoom('В-308'),
        'Ряд 5, правая сторона, место 8');
    final restored = await api.cancel(date: date, slot: '3', room: 'В-308');
    expect(restored.available, 176);
    expect(calls.map((call) => call.method).toList(),
        ['GET', 'POST', 'DELETE']);
    api.dispose();
  });

  test('old backend cannot silently book M-307 instead of selected room',
      () async {
    final api = ClassroomBookingApi(
      client: MockClient((_) async => http.Response(jsonEncode({
        'room': 'М-307', 'date': '2026-11-10', 'slot': '1',
        'testMode': true, 'occupied': [], 'mine': null,
      }), 200)),
    );
    await expectLater(
      () => api.load(
        date: DateTime(2026, 11, 10),
        slot: '1', room: 'В-308', trySession: false,
      ),
      throwsA(isA<ClassroomBookingException>()),
    );
    api.dispose();
  });

  testWidgets('student selects, reserves and cancels one seat',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
          api: api,
          lessonDate: DateTime.now().add(const Duration(days: 2)),
          lessonTime: '09:20 - 10:55',
        ),
    ));
    await tester.pumpAndSettle();

    final seat = find.byKey(const ValueKey('room-seat-1-1-2'));
    await tester.ensureVisible(seat);
    await tester.tap(seat);
    await tester.pumpAndSettle();

    final reserve = find.byKey(const ValueKey('booking-confirm'));
    await tester.ensureVisible(reserve);
    await tester.tap(reserve);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Забронировать').last);
    await tester.pumpAndSettle();

    expect(api.reservations, 1);
    expect(find.byKey(const ValueKey('booking-cancel')), findsOneWidget);
    final cancel = find.byKey(const ValueKey('booking-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Отменить бронь').last);
    await tester.pumpAndSettle();
    expect(api.cancellations, 1);
    expect(find.byKey(const ValueKey('booking-confirm')), findsOneWidget);
  });

  testWidgets('booking screen starts with the selected lesson interval',
      (tester) async {
    final lessonDate = DateTime.now().add(const Duration(days: 3));
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: lessonDate,
        lessonTime: '13:45 - 15:20',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-fixed-lesson')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('booking-date')), findsNothing);
    expect(find.text('13:45 - 15:20'), findsOneWidget);
    expect(api.lastSlot, '3');
    expect(ClassroomBookingApi.dateKey(api.lastDate!),
        ClassroomBookingApi.dateKey(lessonDate));
  });

  testWidgets('M-307 booking does not offer a classroom switch',
      (tester) async {
    final api = _FakeBookingApi();
    final date = DateTime.now().add(const Duration(days: 2));
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: date,
        lessonTime: '13:45 - 15:20',
        initialRoom: 'М-307 (Корпус М)',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('М-307'), findsOneWidget);
    expect(api.loadedRooms, ['М-307']);
    expect(find.byKey(const ValueKey('booking-room-change')), findsNothing);
    expect(find.byKey(const ValueKey('booking-room-input')), findsNothing);
    expect(find.byKey(const ValueKey('booking-confirm')), findsOneWidget);
    expect(api.lastSlot, '3');
  });

  testWidgets('В-308 opens its own amphitheater with 176 places',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: DateTime.now().add(const Duration(days: 2)),
        lessonTime: '13:45 - 15:20',
        initialRoom: 'В-308 (Корпус В)',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('В-308'), findsOneWidget);
    expect(find.textContaining('176 мест'), findsOneWidget);
    expect(find.textContaining('Свободно: 176/176'), findsOneWidget);
    expect(find.byType(AmphitheaterSeatMap), findsOneWidget);
    expect(find.byType(ClassroomSeatMap), findsNothing);
    expect(api.loadedRooms, ['В-308']);
    expect(api.lastSlot, '3');
    expect(find.byKey(const ValueKey('booking-room-change')), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('unsupported room is not bookable even via old entry point',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: DateTime.now().add(const Duration(days: 2)),
        lessonTime: '09:20 - 10:55',
        initialRoom: 'С-401 (Корпус С)',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Бронирование недоступно'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-confirm')), findsNothing);
    expect(find.byKey(const ValueKey('booking-room-change')), findsNothing);
    expect(api.loadedRooms, isEmpty);
  });

  testWidgets('past lesson never silently changes to today or loads seats',
      (tester) async {
    final api = _FakeBookingApi();
    final past = DateTime.now().subtract(const Duration(days: 3));
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: past,
        lessonTime: '09:20 - 10:55',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Бронирование недоступно'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-confirm')), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('booking-date')), findsNothing);
    expect(api.lastDate, isNull);
  });

  testWidgets('unknown lesson time cannot fall back to another slot',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(
        api: api,
        lessonDate: DateTime.now().add(const Duration(days: 3)),
        lessonTime: '08:00 - 09:00',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Бронирование недоступно'), findsOneWidget);
    expect(api.lastSlot, isNull);
    expect(find.byKey(const ValueKey('booking-confirm')), findsNothing);
  });

  testWidgets('booking screen shows test warning and a 54-seat layout',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomBookingScreen(
          api: api,
          lessonDate: DateTime.now().add(const Duration(days: 2)),
          lessonTime: '09:20 - 10:55',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('М-307'), findsOneWidget);
    expect(find.textContaining('54 посадочных места'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-free-count')), findsOneWidget);
    expect(find.textContaining('Тестовое бронирование для М-307 и В-308'), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-3-9-2')), findsOneWidget);
  });
}

class _FakeBookingApi extends ClassroomBookingApi {
  final _mineByRoom = <String, ClassroomSeat>{};
  final loadedRooms = <String>[];
  int reservations = 0;
  int cancellations = 0;
  DateTime? lastDate;
  String? lastSlot;

  ClassroomAvailability _snapshot(DateTime date, String slot, String room) {
    final mine = _mineByRoom[room];
    return ClassroomAvailability(
      room: room,
      date: ClassroomBookingApi.dateKey(date),
      slot: slot,
      occupied: mine == null ? <ClassroomSeat>{} : {mine},
      mine: mine,
      slots: classroomDemoSlots,
      testMode: true,
    );
  }

  @override
  Future<ClassroomAvailability> load({
    required DateTime date,
    required String slot,
    String room = 'М-307',
    bool trySession = true,
  }) async {
    lastDate = date;
    lastSlot = slot;
    loadedRooms.add(room);
    return _snapshot(date, slot, room);
  }

  @override
  Future<ClassroomAvailability> reserve({
    required DateTime date,
    required String slot,
    required ClassroomSeat seat,
    String room = 'М-307',
  }) async {
    if (_mineByRoom.containsKey(room)) {
      throw const ClassroomBookingException('Занято');
    }
    _mineByRoom[room] = seat;
    reservations++;
    return _snapshot(date, slot, room);
  }

  @override
  Future<ClassroomAvailability> cancel({
    required DateTime date,
    required String slot,
    String room = 'М-307',
  }) async {
    _mineByRoom.remove(room);
    cancellations++;
    return _snapshot(date, slot, room);
  }
}
