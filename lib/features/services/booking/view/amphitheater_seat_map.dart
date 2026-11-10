import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/classroom_booking_api.dart';
import '/features/services/style/service_palette.dart';

/// The V-308 amphitheater has two curved banks and a central aisle.
/// Upper four rows: 10 seats per side. Lower six: 8 seats per side.
/// Existing seat identifiers stay unchanged:
/// row = tier (1..10), desk = seat number (1..10), seat = side (1/2).
///
/// The entire auditorium is visible at first. Pinch to zoom / drag to pan
/// for comfortable seat selection on small phones.
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

class _AuditoriumGeometry {
  static const width = 830.0;
  static const height = 875.0;
  static const left = 90.0;
  static const right = 438.0;
  static const seatStep = 30.0;
  static const seatWidth = 27.0;
  static const seatHeight = 34.0;
  static const arcDepth = 24.0;

  static int count(int row) => row <= 4 ? 10 : 8;

  static double rowTop(int row) =>
      98.0 + (row - 1) * 63.0 + (row >= 5 ? 26.0 : 0.0);

  // Shorter blue rows retract toward the outside walls, not away from
  // the central aisle. Their inner-most seats align with the red rows.
  static double x(int side, int index, int count) =>
      (side == 1 ? left + (10 - count) * seatStep : right) +
      index * seatStep;

  static double arcOffset(int index, int count) {
    final middle = (count - 1) / 2;
    final normalized = (index - middle) / middle;
    return arcDepth * normalized * normalized;
  }
}

class _CurvedRowGuides extends CustomPainter {
  const _CurvedRowGuides();

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 1; row <= 10; row++) {
      final count = _AuditoriumGeometry.count(row);
      final y = _AuditoriumGeometry.rowTop(row) +
          _AuditoriumGeometry.seatHeight / 2;
      final paint = Paint()
        ..color = (row <= 4
                ? const Color(0xFFE46D78)
                : const Color(0xFF7398F8))
            .withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (var side = 1; side <= 2; side++) {
        final first = _AuditoriumGeometry.x(side, 0, count) +
            _AuditoriumGeometry.seatWidth / 2;
        final last = _AuditoriumGeometry.x(side, count - 1, count) +
            _AuditoriumGeometry.seatWidth / 2;
        final path = Path()
          ..moveTo(first, y + _AuditoriumGeometry.arcDepth)
          ..quadraticBezierTo(
            (first + last) / 2,
            y - _AuditoriumGeometry.arcDepth,
            last,
            y + _AuditoriumGeometry.arcDepth,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedRowGuides oldDelegate) => false;
}

class _AmphitheaterSeatMapState extends State<AmphitheaterSeatMap> {
  static const _free = Color(0xFF3F9870);
  static const _taken = Color(0xFF55555D);
  static const _mine = Color(0xFFF0BF78);
  static const _red = Color(0xFFE46D78);
  static const _blue = Color(0xFF7398F8);

  final TransformationController _transform = TransformationController();
  Size? _viewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double _fitScale(Size viewport) => math.min(
        viewport.width / _AuditoriumGeometry.width,
        viewport.height / _AuditoriumGeometry.height,
      );

  Matrix4 _fitMatrix(Size viewport) {
    final scale = _fitScale(viewport);
    return Matrix4.identity()
      ..translate(
        (viewport.width - _AuditoriumGeometry.width * scale) / 2,
        (viewport.height - _AuditoriumGeometry.height * scale) / 2,
      )
      ..scale(scale);
  }

  void _showAll() {
    final viewport = _viewport;
    if (viewport != null) _transform.value = _fitMatrix(viewport);
  }

  void _zoom(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final original = _transform.value;
    final oldScale = original.getMaxScaleOnAxis();
    final scale = (oldScale * factor).clamp(_fitScale(viewport), 3.2).toDouble();
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final sceneCenter = MatrixUtils.transformPoint(
      Matrix4.inverted(original),
      center,
    );
    _transform.value = Matrix4.identity()
      ..translate(
        center.dx - sceneCenter.dx * scale,
        center.dy - sceneCenter.dy * scale,
      )
      ..scale(scale);
  }

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

  Widget _seat(ClassroomSeat place, int index, int count) {
    final own = place == widget.mine;
    final taken = widget.occupied.contains(place);
    final selected = place == widget.selected;
    final canChoose = !widget.disabled && widget.mine == null && !taken;
    final fill = own
        ? _mine
        : taken
            ? _taken
            : selected
                ? ServicePalette.accent
                : _free;
    final status = own
        ? 'моё место'
        : taken
            ? 'занято'
            : selected
                ? 'выбрано'
                : 'свободно';
    final t = (index - (count - 1) / 2) / ((count - 1) / 2);

    return Positioned(
      left: _AuditoriumGeometry.x(place.seat, index, count),
      top: _AuditoriumGeometry.rowTop(place.row) +
          _AuditoriumGeometry.arcOffset(index, count),
      child: Transform.rotate(
        angle: t * 0.13,
        child: Semantics(
          label: '${place.labelForRoom('В-308')}, $status',
          button: true,
          enabled: canChoose,
          selected: own || selected,
          child: InkWell(
            key: ValueKey('room-seat-${place.identifier}'),
            onTap: canChoose ? () => widget.onSelected(place) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: _AuditoriumGeometry.seatWidth,
              height: _AuditoriumGeometry.seatHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: own
                  ? const Icon(Icons.check, size: 15, color: Colors.black87)
                  : selected
                      ? Text(
                          '${place.desk}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _seatWidgets() {
    final result = <Widget>[];
    for (var row = 1; row <= 10; row++) {
      final count = _AuditoriumGeometry.count(row);
      for (var side = 1; side <= 2; side++) {
        for (var index = 0; index < count; index++) {
          // Seat 1 is closest to the aisle on either side.
          final number = side == 1 ? count - index : index + 1;
          result.add(_seat(
            ClassroomSeat(row: row, desk: number, seat: side),
            index,
            count,
          ));
        }
      }
    }
    return result;
  }

  Widget _rowMarker(int row) {
    final color = row <= 4 ? _red : _blue;
    return Positioned(
      key: ValueKey('amphitheater-row-$row'),
      top: _AuditoriumGeometry.rowTop(row) + 9,
      left: 395,
      width: 40,
      child: Center(
        child: Text(
          '$row',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _mapScene(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _AuditoriumGeometry.width,
      height: _AuditoriumGeometry.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _CurvedRowGuides()),
          ),
          Positioned(
            top: 10,
            left: 275,
            width: 280,
            child: Text(
              'ЗАДНЯЯ ЧАСТЬ АУДИТОРИИ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Positioned(
            top: 38,
            left: 100,
            width: 285,
            child: Text(
              'ЛЕВАЯ СТОРОНА',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            top: 38,
            left: 440,
            width: 285,
            child: Text(
              'ПРАВАЯ СТОРОНА',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            key: ValueKey('amphitheater-red-zone'),
            top: 63,
            left: 70,
            width: 690,
            child: Text(
              'КРАСНАЯ ЗОНА · 4 РЯДА × 20 МЕСТ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Positioned(
            key: ValueKey('amphitheater-blue-zone'),
            top: 348,
            left: 70,
            width: 690,
            child: Text(
              'СИНЯЯ ЗОНА · 6 РЯДОВ × 16 МЕСТ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            left: 393,
            top: 91,
            width: 44,
            height: 648,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          for (var row = 1; row <= 10; row++) _rowMarker(row),
          ..._seatWidgets(),
          Positioned(
            left: 175,
            top: 790,
            width: 480,
            height: 51,
            child: Container(
              key: const ValueKey('room-board'),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const Text(
                'ЭКРАН / ПРЕПОДАВАТЕЛЬ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final height = math.min(690.0, math.max(410.0, width * 1.16));
        final viewport = Size(width, height);

        if (_viewport == null) {
          // This runs before the InteractiveViewer is created, so it is safe
          // to set the initial fit matrix synchronously.
          _viewport = viewport;
          _transform.value = _fitMatrix(viewport);
        } else if (_viewport != viewport) {
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _viewport == viewport) _showAll();
          });
        }

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
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Весь зал · 176 мест',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const ValueKey('amphitheater-zoom-out'),
                  tooltip: 'Отдалить',
                  onPressed: () => _zoom(0.75),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  key: const ValueKey('amphitheater-zoom-in'),
                  tooltip: 'Приблизить',
                  onPressed: () => _zoom(1.5),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                TextButton(
                  key: const ValueKey('amphitheater-show-all'),
                  onPressed: _showAll,
                  child: const Text('Весь зал'),
                ),
              ],
            ),
            Container(
              key: const ValueKey('amphitheater-viewport'),
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(850),
                minScale: _fitScale(viewport),
                maxScale: 3.2,
                panEnabled: true,
                scaleEnabled: true,
                child: _mapScene(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Вся аудитория показана сразу. Раздвинь пальцы или нажми «+», '
              'чтобы увеличить места; перемещай схему пальцем.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }
}
