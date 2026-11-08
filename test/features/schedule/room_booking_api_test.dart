import 'package:campusapp/features/schedule/room_booking/room_booking_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Classroom booking in the timetable', () {
    test('only enabled classroom codes have a booking action', () {
      expect(RoomBookingApi.supportedRoom('М-307 (Корпус М)'), 'М-307');
      expect(RoomBookingApi.supportedRoom('M-307'), 'М-307');
      expect(RoomBookingApi.supportedRoom('В-308 (Корпус В)'), 'В-308');
      expect(RoomBookingApi.supportedRoom('B-308'), 'В-308');
      expect(RoomBookingApi.supportedRoom('V-308'), 'В-308');
      expect(RoomBookingApi.supportedRoom('В-3080'), isNull);
      expect(RoomBookingApi.supportedRoom('В-309'), isNull);
      expect(RoomBookingApi.supportedRoom('С-401'), isNull);
    });

    test('lesson interval is taken from the schedule, not chosen again', () {
      expect(RoomBookingApi.slotFromTime('09:20–10:55'), '1');
      expect(RoomBookingApi.slotFromTime('11:10 - 12:45'), '2');
      expect(RoomBookingApi.slotFromTime('13:45–15:20'), '3');
      expect(RoomBookingApi.slotFromTime('15:35–17:10'), '4');
      expect(RoomBookingApi.slotFromTime('17:20–18:55'), '5');
      expect(RoomBookingApi.slotFromTime('19:05–20:40'), '6');
      expect(RoomBookingApi.slotFromTime('Дистанционно'), isNull);
    });

    test('booked seat coordinates and ownership are interpreted correctly', () {
      final availability = RoomAvailability.fromJson({
        'capacity': 176,
        'available': 175,
        'occupied': [
          {'row': 4, 'desk': 10, 'seat': 2, 'mine': true},
        ],
        'mine': {'row': 4, 'desk': 10, 'seat': 2, 'mine': true},
      });

      expect(availability.capacity, 176);
      expect(availability.available, 175);
      expect(availability.occupied.single.key, '4:10:2');
      expect(availability.mine?.mine, isTrue);
    });
  });
}
