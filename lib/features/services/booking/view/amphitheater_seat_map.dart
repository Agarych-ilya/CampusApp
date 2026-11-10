import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/classroom_booking_api.dart';
import '/features/services/style/service_palette.dart';

/// V-308 is divided by a central aisle:
/// 4 upper tiers with 10 places per side, then 6 lower tiers with 8.
/// The existing API maps row=tier, desk=place number, seat=side (1/2).
///
/// A phone cannot fit twenty usable tappable seats across its width.
/// On narrow screens, show one complete bank at a time; on wider screens
/// both banks are visible. This is only a layout change, not a new seat ID.
class AmphitheaterSeatMap extends StatefulWidget {
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

  @override
  State<AmphitheaterSeatMap> createState() => _AmphitheaterSeatMapState();
}

class _AmphitheaterSeatMapState extends State<AmphitheaterSeatMap> {
  static const _free = Color(0xFF3F9870);
  static const _taken = Color(0xFF55555D);
  static const _mine = Color(0xFFF0BF78);
  static const _red = Color(0xFFE46D78);
  static const _blue = Color(0xFF7398F8);
  static const _aisleWidth = 44.0;
  static const _seatGap = 3.0;

  // On phones, each bank has its own visible tab. A selected seat is not
  // reset when switching banks; the parent controls the selected seat.
  int _visibleSide = 1;

  Widget _legend(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
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
    final own = place == widget.mine;
    final taken = widget.occupied.contains(place);
    final selectedNow = place == widget.selected;
    final canChoose = !widget.disabled && widget.mine == null && !taken;
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
        onTap: canChoose ? () => widget.onSelected(place) : null,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: seatWidth,
          height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selectedNow ? Colors.white : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: own
              ? const Icon(Icons.check, size: 15, color: Colors.black87)
              : selectedNow
                  ? Text(
                      '${place.desk}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: math.min(seatWidth * 0.46, 12),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _bank(
    BuildContext context, {
    required int row,
    required int side,
    required int count,
    required double seatWidth,
  }) {
    // Number 1 is always by the aisle on either side.
    final numbers = side == 1
        ? List<int>.generate(count, (i) => count - i)
        : List<int>.generate(count, (i) => i + 1);
    return Row(
      mainAxisAlignment:
          side == 1 ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        for (var i = 0; i < numbers.length; i++) ...[
          if (i > 0) const SizedBox(width: _seatGap),
          _seat(
            context,
            ClassroomSeat(row: row, desk: numbers[i], seat: side),
            seatWidth,
          ),
        ],
      ],
    );
  }

  Widget _aisle(BuildContext context, int row, {required bool compact}) {
    return SizedBox(
      width: _aisleWidth,
      height: 37,
      child: Center(
        child: Text(
          '$row',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 12 : 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _zoneHeader(int row) {
    return Padding(
      padding: EdgeInsets.only(top: row == 5 ? 12 : 1, bottom: 9),
      child: Text(
        row <= 4
            ? 'Красная зона · 10 мест с каждой стороны'
            : 'Синяя зона · 8 мест с каждой стороны',
        key: ValueKey(
          row == 1 ? 'amphitheater-red-zone' : 'amphitheater-blue-zone',
        ),
        style: TextStyle(
          color: row <= 4 ? _red : _blue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required int row,
    required bool compact,
    required double seatWidth,
  }) {
    final count = row <= 4 ? 10 : 8;
    final color = row <= 4 ? _red : _blue;
    return Container(
      key: ValueKey('amphitheater-row-$row'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          if (!compact || _visibleSide == 1)
            Expanded(
              child: _bank(
                context,
                row: row,
                side: 1,
                count: count,
                seatWidth: seatWidth,
              ),
            ),
          _aisle(context, row, compact: compact),
          if (!compact || _visibleSide == 2)
            Expanded(
              child: _bank(
                context,
                row: row,
                side: 2,
                count: count,
                seatWidth: seatWidth,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sideSelector() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('amphitheater-side-left'),
            onPressed: () => setState(() => _visibleSide = 1),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _visibleSide == 1 ? ServicePalette.accent.withOpacity(0.13) : null,
              side: BorderSide(
                color: _visibleSide == 1
                    ? ServicePalette.accent
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: const Text('Слева · 88 мест', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('amphitheater-side-right'),
            onPressed: () => setState(() => _visibleSide = 2),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _visibleSide == 2 ? ServicePalette.accent.withOpacity(0.13) : null,
              side: BorderSide(
                color: _visibleSide == 2
                    ? ServicePalette.accent
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: const Text('Справа · 88 мест', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The whole room needs 20 seats and an aisle. At phone widths,
        // use a sector switch instead of squashing the seats to ~12 px.
        final compact = constraints.maxWidth < 700;
        final bankWidth = compact
            ? constraints.maxWidth - _aisleWidth
            : (constraints.maxWidth - _aisleWidth) / 2;
        final seatWidth = math.max(
          0.0,
          math.min(34.0, (bankWidth - 9 * _seatGap - 2) / 10),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 7,
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
            const SizedBox(height: 14),
            if (compact) ...[
              _sideSelector(),
              const SizedBox(height: 5),
              Text(
                'Показана ${_visibleSide == 1 ? 'левая' : 'правая'} сторона. '
                'Переключай сторону, чтобы выбрать любое из 176 мест.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ] else
              const Row(
                children: [
                  Expanded(
                    child: Text('Левая сторона',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11)),
                  ),
                  SizedBox(
                    width: _aisleWidth,
                    child: Text('Проход',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10)),
                  ),
                  Expanded(
                    child: Text('Правая сторона',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            for (var row = 1; row <= 10; row++) ...[
              if (row == 1 || row == 5) _zoneHeader(row),
              _row(
                context,
                row: row,
                compact: compact,
                seatWidth: seatWidth,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Места нумеруются от центрального прохода к стенам. '
              'Ряды — от экрана к задней части зала.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
