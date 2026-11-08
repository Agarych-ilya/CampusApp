import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusapp/features/services/booking/data/classroom_booking_api.dart';
import 'package:campusapp/features/services/booking/view/classroom_booking_screen.dart';
import 'package:campusapp/features/services/booking/view/classroom_seat_map.dart';

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
    api.dispose();
  });

  testWidgets('student selects, reserves and cancels one seat',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: ClassroomBookingScreen(api: api),
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

  testWidgets('booking screen shows test warning and a 54-seat layout',
      (tester) async {
    final api = _FakeBookingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomBookingScreen(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('М-307'), findsOneWidget);
    expect(find.textContaining('54 посадочных места'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-free-count')), findsOneWidget);
    expect(find.textContaining('Тестовое бронирование'), findsOneWidget);
    expect(find.byKey(const ValueKey('room-seat-3-9-2')), findsOneWidget);
  });
}

class _FakeBookingApi extends ClassroomBookingApi {
  ClassroomSeat? _mine;
  int reservations = 0;
  int cancellations = 0;

  ClassroomAvailability _snapshot(DateTime date, String slot) =>
      ClassroomAvailability(
        room: 'М-307',
        date: ClassroomBookingApi.dateKey(date),
        slot: slot,
        occupied: _mine == null ? <ClassroomSeat>{} : {_mine!},
        mine: _mine,
        slots: classroomDemoSlots,
        testMode: true,
      );

  @override
  Future<ClassroomAvailability> load({
    required DateTime date,
    required String slot,
    bool trySession = true,
  }) async => _snapshot(date, slot);

  @override
  Future<ClassroomAvailability> reserve({
    required DateTime date,
    required String slot,
    required ClassroomSeat seat,
  }) async {
    if (_mine != null) throw const ClassroomBookingException('Занято');
    _mine = seat;
    reservations++;
    return _snapshot(date, slot);
  }

  @override
  Future<ClassroomAvailability> cancel({
    required DateTime date,
    required String slot,
  }) async {
    _mine = null;
    cancellations++;
    return _snapshot(date, slot);
  }
}
