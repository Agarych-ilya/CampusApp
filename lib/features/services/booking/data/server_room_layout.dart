/// JSON room geometry supplied by Campus-backend / MySQL.
/// Flutter does not need per-auditorium seating coordinates.
class ServerRoomLayoutSeat {
  const ServerRoomLayoutSeat({
    required this.row,
    required this.desk,
    required this.seat,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.label,
  });

  final int row;
  final int desk;
  final int seat;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final String label;

  String get id => '$row-$desk-$seat';

  factory ServerRoomLayoutSeat.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Некорректное место');
    final row = _readInt(value, 'row');
    final desk = _readInt(value, 'desk');
    final seat = _readInt(value, 'seat');
    final x = _readDouble(value, 'x');
    final y = _readDouble(value, 'y');
    final width = _readDouble(value, 'width');
    final height = _readDouble(value, 'height');
    final rotation = _readDouble(value, 'rotation', fallback: 0);
    if (row <= 0 || row > 100 || desk <= 0 || desk > 100 ||
        seat <= 0 || seat > 20 || x < 0 || y < 0 ||
        width < 8 || height < 8) {
      throw const FormatException('Неверные размеры места');
    }
    return ServerRoomLayoutSeat(
      row: row, desk: desk, seat: seat,
      x: x, y: y, width: width, height: height, rotation: rotation,
      label: _shortText(value['label']),
    );
  }
}

class ServerRoomLayoutElement {
  const ServerRoomLayoutElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.x2,
    required this.y2,
    required this.cx,
    required this.cy,
    required this.text,
    required this.color,
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double x2;
  final double y2;
  final double cx;
  final double cy;
  final String text;
  final String color;

  factory ServerRoomLayoutElement.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Некорректный элемент');
    final id = value['id']?.toString() ?? '';
    final type = value['type']?.toString() ?? '';
    const allowed = {'rect', 'line', 'curve', 'label', 'outlet'};
    if (id.isEmpty || id.length > 100 || !allowed.contains(type)) {
      throw const FormatException('Неизвестный элемент схемы');
    }
    return ServerRoomLayoutElement(
      id: id,
      type: type,
      x: _readDouble(value, 'x'),
      y: _readDouble(value, 'y'),
      width: _readDouble(value, 'width', fallback: 0),
      height: _readDouble(value, 'height', fallback: 0),
      x2: _readDouble(value, 'x2', fallback: 0),
      y2: _readDouble(value, 'y2', fallback: 0),
      cx: _readDouble(value, 'cx', fallback: 0),
      cy: _readDouble(value, 'cy', fallback: 0),
      text: _shortText(value['text']),
      color: value['color']?.toString() ?? '',
    );
  }
}

class ServerRoomLayout {
  ServerRoomLayout({
    required this.room,
    required this.university,
    required this.building,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.seats,
    required this.elements,
  }) : seatIds = seats.map((seat) => seat.id).toSet();

  final String room;
  final String university;
  final String building;
  final String name;
  final String description;
  final double width;
  final double height;
  final List<ServerRoomLayoutSeat> seats;
  final List<ServerRoomLayoutElement> elements;
  final Set<String> seatIds;

  bool includesSeat(int row, int desk, int seat) =>
      seatIds.contains('$row-$desk-$seat');

  String? seatLabel(int row, int desk, int seat) {
    for (final position in seats) {
      if (position.row == row && position.desk == desk &&
          position.seat == seat && position.label.isNotEmpty) {
        return position.label;
      }
    }
    return null;
  }

  factory ServerRoomLayout.fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) {
      throw const FormatException('Неизвестная версия схемы аудитории');
    }
    final room = value['room']?.toString() ?? '';
    final width = _readDouble(value, 'width');
    final height = _readDouble(value, 'height');
    if (room.isEmpty || width < 100 || height < 100 ||
        width > 10000 || height > 10000 ||
        value['seats'] is! List || value['elements'] is! List) {
      throw const FormatException('Некорректная схема аудитории');
    }
    final seats = (value['seats'] as List)
        .map(ServerRoomLayoutSeat.fromJson).toList();
    final elements = (value['elements'] as List)
        .map(ServerRoomLayoutElement.fromJson).toList();
    if (seats.isEmpty || seats.length > 5000 || elements.length > 10000 ||
        seats.map((seat) => seat.id).toSet().length != seats.length ||
        seats.any((seat) =>
            seat.x + seat.width > width || seat.y + seat.height > height)) {
      throw const FormatException('Ошибка координат мест аудитории');
    }
    return ServerRoomLayout(
      room: room,
      university: value['university']?.toString() ?? '',
      building: value['building']?.toString() ?? '',
      name: value['name']?.toString() ?? room,
      description: value['description']?.toString() ?? '',
      width: width,
      height: height,
      seats: seats,
      elements: elements,
    );
  }
}

String _shortText(Object? value) {
  final text = value?.toString() ?? '';
  return text.length <= 200 ? text : text.substring(0, 200);
}

int _readInt(Map source, String key) {
  final value = source[key];
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('Некорректное целое значение: $key');
}

double _readDouble(Map source, String key, {double? fallback}) {
  final value = source[key];
  if (value == null && fallback != null) return fallback;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Некорректная координата: $key');
}
