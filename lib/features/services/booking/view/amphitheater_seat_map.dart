import 'package:flutter/material.dart';

import '../data/classroom_booking_api.dart';
import '/features/services/style/service_palette.dart';

/// В-308: two banks separated by a central aisle.
/// Four upper (red) rows hold 10 seats on each side;
/// six lower (blue) rows hold 8 seats on each side.
/// row = tier 1..10, desk = seat number 1..10, seat = side (1 left/2 right).
class AmphitheaterSeatMap extends StatelessWidget {
  const AmphitheaterSeatMap({
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

  static const _free = Color(0xFF3F9870);
  static const _taken = Color(0xFF55555D);
  static const _mine = Color(0xFFF0BF78);
  static const _red = Color(0xFFE46D78);
  static const _blue = Color(0xFF7398F8);

  Widget _legend(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _seat(BuildContext context, ClassroomSeat place, double seatWidth) {
    final own = place == mine;
    final taken = occupied.contains(place);
    final selectedNow = place == selected;
    final canChoose = !disabled && mine == null && !taken;
    final fill = own
        ? _mine
        : taken
            ? _taken
            : selectedNow
                ? ServicePalette.accent
                : _free;
    final state = own
        ? 'моё место'
        : taken
            ? 'занято'
            : selectedNow
                ? 'выбрано'
                : 'свободно';

    return Semantics(
      label: '${place.labelForRoom('В-308')}, $state',
      button: true,
      enabled: canChoose,
      selected: own || selectedNow,
      child: InkWell(
        key: ValueKey('room-seat-${place.identifier}'),
        onTap: canChoose ? () => onSelected(place) : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: seatWidth,
          height: 25,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selectedNow ? Colors.white : Colors.transparent,
              width: 1.3,
            ),
          ),
          alignment: Alignment.center,
          child: own ? const Icon(
            Icons.check, size: 11, color: Colors.black87,
          ) : null,
        ),
      ),
    );
  }

  Widget _bank(
    BuildContext context, {
    required int row,
    required int count,
    required int side,
    required double width,
  }) {
    final seats = side == 1
        ? List<int>.generate(count, (i) => count - i)
        : List<int>.generate(count, (i) => i + 1);
    return Row(
      mainAxisAlignment:
          side == 1 ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        for (final number in seats) ...[
          if (number != seats.first) const SizedBox(width: 2),
          _seat(
            context,
            ClassroomSeat(row: row, desk: number, seat: side),
            width,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit 20 seats and the central aisle on a typical phone screen.
        // The whole amphitheater stays visible without horizontal scrolling.
        final width = constraints.maxWidth;
        const aisleWidth = 40.0;
        const bankGap = 2.0;
        final bankWidth = (width - aisleWidth) / 2;
        final seatWidth =
            ((bankWidth - 9 * bankGap) / 10).clamp(8.0, 22.0).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 11,
              runSpacing: 6,
              children: [
                _legend(_free, 'Свободно'),
                _legend(_taken, 'Занято'),
                _legend(ServicePalette.accent, 'Выбрано'),
                _legend(_mine, 'Моё'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('room-board'),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const Text(
                'Экран / преподаватель',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Левая сторона',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11)),
                ),
                SizedBox(
                  width: aisleWidth,
                  child: const Text(
                    'Проход',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9),
                  ),
                ),
                const Expanded(
                  child: Text('Правая сторона',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (var row = 1; row <= 10; row++) ...[
              if (row == 1 || row == 5)
                Padding(
                  padding: EdgeInsets.only(
                    top: row == 5 ? 9 : 0,
                    bottom: 8,
                  ),
                  child: Text(
                    row <= 4
                        ? 'Красная зона · 10 мест с каждой стороны'
                        : 'Синяя зона · 8 мест с каждой стороны',
                    key: ValueKey(row == 1
                        ? 'amphitheater-red-zone'
                        : 'amphitheater-blue-zone'),
                    style: TextStyle(
                      color: row <= 4 ? _red : _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                key: ValueKey('amphitheater-row-$row'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: (row <= 4 ? _red : _blue).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (row <= 4 ? _red : _blue).withOpacity(0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _bank(
                        context, row: row,
                        count: row <= 4 ? 10 : 8,
                        side: 1, width: seatWidth,
                      ),
                    ),
                    SizedBox(
                      width: aisleWidth,
                      child: Text(
                        '$row',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _bank(
                        context, row: row,
                        count: row <= 4 ? 10 : 8,
                        side: 2, width: seatWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              'Места нумеруются от центрального прохода к стенам. '
              'Ряды — от экрана к задней части зала.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }
}
