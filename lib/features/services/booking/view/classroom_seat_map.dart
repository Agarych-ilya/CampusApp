import 'package:flutter/material.dart';

import '../data/classroom_booking_api.dart';
import '/features/services/style/service_palette.dart';

/// The M-307 test layout: 3 rows, 9 two-person desks in each row.
class ClassroomSeatMap extends StatelessWidget {
  const ClassroomSeatMap({
    super.key,
    required this.occupied,
    required this.mine,
    required this.selected,
    required this.onSelected,
    this.disabled = false,
  });

  final Set<ClassroomSeat> occupied;
  final ClassroomSeat? mine;
  final ClassroomSeat? selected;
  final ValueChanged<ClassroomSeat> onSelected;
  final bool disabled;

  static const Color _available = Color(0xFF3F9870);
  static const Color _booked = Color(0xFF55555D);
  static const Color _mySeat = Color(0xFFF0BF78);

  Widget _seat(ClassroomSeat seat) {
    final isMine = seat == mine;
    final taken = occupied.contains(seat);
    final isSelected = seat == selected;
    final color = isMine
        ? _mySeat
        : taken
            ? _booked
            : isSelected
                ? ServicePalette.accent
                : _available;
    final canSelect = !disabled && mine == null && !taken;

    return Semantics(
      label: '${seat.label}, '
          '${isMine ? 'моё место' : taken ? 'занято' : isSelected ? 'выбрано' : 'свободно'}',
      button: true,
      enabled: canSelect,
      selected: isSelected || isMine,
      child: InkWell(
        key: ValueKey('room-seat-${seat.identifier}'),
        borderRadius: BorderRadius.circular(7),
        onTap: canSelect ? () => onSelected(seat) : null,
        child: Container(
          width: 22,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: isMine
              ? const Icon(Icons.check, size: 14, color: Colors.black87)
              : null,
        ),
      ),
    );
  }

  Widget _desk(int row, int desk) {
    return Column(
      key: ValueKey('room-desk-$row-$desk'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seat(ClassroomSeat(row: row, desk: desk, seat: 1)),
            const SizedBox(width: 3),
            _seat(ClassroomSeat(row: row, desk: desk, seat: 2)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          width: 47,
          decoration: BoxDecoration(
            color: const Color(0xFF777781).withOpacity(0.45),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Парта $desk',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9F9FA8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 13,
          runSpacing: 6,
          children: [
            _legend(_available, 'Свободно'),
            _legend(_booked, 'Занято'),
            _legend(ServicePalette.accent, 'Выбрано'),
            _legend(_mySeat, 'Моё'),
          ],
        ),
        const SizedBox(height: 17),
        Container(
          key: const ValueKey('room-board'),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            'Доска / преподаватель',
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ),
        const SizedBox(height: 18),
        // Three vertical columns, each containing nine two-person desks.
        // The first desk is closest to the board.
        Row(
          key: const ValueKey('room-vertical-rows'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 1; row <= 3; row++)
              Expanded(
                child: Column(
                  key: ValueKey('room-row-$row'),
                  children: [
                    Text(
                      'Ряд $row',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var desk = 1; desk <= 9; desk++) ...[
                      _desk(row, desk),
                      if (desk < 9) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
