import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/classroom_booking_api.dart';
import '../data/server_room_layout.dart';
import '/features/services/style/service_palette.dart';

/// A single Flutter renderer for every classroom supplied by Campus-backend.
/// Seat positions, rows, board, aisles and outlets are all loaded from MySQL.
class ServerRoomSeatMap extends StatefulWidget {
  const ServerRoomSeatMap({
    super.key,
    required this.layout,
    required this.occupied,
    required this.mine,
    required this.selected,
    required this.onSelected,
    this.disabled = false,
  });

  final ServerRoomLayout layout;
  final Set<ClassroomSeat> occupied;
  final ClassroomSeat? mine;
  final ClassroomSeat? selected;
  final ValueChanged<ClassroomSeat> onSelected;
  final bool disabled;

  @override
  State<ServerRoomSeatMap> createState() => _ServerRoomSeatMapState();
}

class _ServerRoomSeatMapState extends State<ServerRoomSeatMap> {
  static const _free = Color(0xFF3F9870);
  static const _taken = Color(0xFF55555D);
  static const _mine = Color(0xFFF0BF78);
  final TransformationController _transform = TransformationController();
  Size? _viewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double _fitScale(Size viewport) => math.min(
        viewport.width / widget.layout.width,
        viewport.height / widget.layout.height,
      );

  Matrix4 _fitMatrix(Size viewport) {
    final scale = _fitScale(viewport);
    return Matrix4.identity()
      ..translate(
        (viewport.width - widget.layout.width * scale) / 2,
        (viewport.height - widget.layout.height * scale) / 2,
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
    final old = _transform.value;
    final oldScale = old.getMaxScaleOnAxis();
    final scale = (oldScale * factor).clamp(_fitScale(viewport), 4.0).toDouble();
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final sceneCenter = MatrixUtils.transformPoint(
      Matrix4.inverted(old), center,
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

  Widget _seat(ServerRoomLayoutSeat position) {
    final seat = ClassroomSeat(
      row: position.row, desk: position.desk, seat: position.seat,
    );
    final own = seat == widget.mine;
    final taken = widget.occupied.contains(seat);
    final selected = seat == widget.selected;
    final available = !widget.disabled && widget.mine == null && !taken;
    final color = own
        ? _mine
        : taken
            ? _taken
            : selected
                ? ServicePalette.accent
                : _free;
    final status = own ? 'моё место' : taken ? 'занято' :
        selected ? 'выбрано' : 'свободно';

    return Positioned(
      left: position.x,
      top: position.y,
      child: Transform.rotate(
        angle: position.rotation,
        child: Semantics(
          label: '${seat.labelForRoom(widget.layout.room)}, $status',
          button: true,
          enabled: available,
          selected: own || selected,
          child: InkWell(
            key: ValueKey('room-seat-${seat.identifier}'),
            onTap: available ? () => widget.onSelected(seat) : null,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: position.width,
              height: position.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: own
                  ? const Icon(Icons.check, size: 14, color: Colors.black87)
                  : selected
                      ? Text('${seat.desk}', style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ))
                      : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlet(ServerRoomLayoutElement element) {
    return Positioned(
      left: element.x,
      top: element.y,
      child: Tooltip(
        message: element.text,
        child: Icon(
          Icons.power_outlined,
          key: ValueKey('room-outlet-${element.id}'),
          size: 20,
          color: _mine,
          semanticLabel: element.text,
        ),
      ),
    );
  }

  Widget _scene(BuildContext context) {
    return SizedBox(
      width: widget.layout.width,
      height: widget.layout.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoomElementsPainter(
                elements: widget.layout.elements,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
          for (final item in widget.layout.elements)
            if (item.type == 'outlet') _outlet(item),
          for (final position in widget.layout.seats) _seat(position),
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
        final height = math.min(690.0, math.max(390.0, width * 1.18));
        final viewport = Size(width, height);
        if (_viewport == null) {
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
                    'Схема аудитории',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const ValueKey('server-map-zoom-out'),
                  tooltip: 'Отдалить',
                  onPressed: () => _zoom(0.75),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  key: const ValueKey('server-map-zoom-in'),
                  tooltip: 'Приблизить',
                  onPressed: () => _zoom(1.5),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                TextButton(
                  key: const ValueKey('server-map-show-all'),
                  onPressed: _showAll,
                  child: const Text('Весь зал'),
                ),
              ],
            ),
            Container(
              key: const ValueKey('server-room-map'),
              height: height,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(850),
                minScale: _fitScale(viewport),
                maxScale: 4,
                panEnabled: true,
                scaleEnabled: true,
                child: _scene(context),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Раздвинь пальцы, чтобы увеличить места, или нажми «+». '
              'Все элементы схемы загружены с сервера.',
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

/// Decorative elements are drawn in the same coordinate system as the seats.
/// Using a painter keeps the layout lightweight even for large rooms.
class _RoomElementsPainter extends CustomPainter {
  const _RoomElementsPainter({
    required this.elements,
    required this.colorScheme,
  });
  final List<ServerRoomLayoutElement> elements;
  final ColorScheme colorScheme;

  Color _color(String type) {
    switch (type) {
      case 'upper':
        return const Color(0xFFE46D78);
      case 'lower':
        return const Color(0xFF7398F8);
      case 'aisle':
        return colorScheme.surfaceContainerHigh;
      case 'block':
        return colorScheme.surfaceContainerHighest;
      default:
        return colorScheme.outlineVariant;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in elements) {
      final color = _color(item.color);
      switch (item.type) {
        case 'rect':
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(item.x, item.y, item.width, item.height),
            const Radius.circular(3),
          );
          canvas.drawRRect(rect,
              Paint()..color = colorScheme.surfaceContainerHigh);
          canvas.drawRRect(
            rect,
            Paint()
              ..color = colorScheme.outlineVariant
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
          if (item.text.isNotEmpty) {
            _drawText(canvas, item.text,
                item.x + item.width / 2, item.y + item.height / 2,
                colorScheme.onSurface, 13, center: true);
          }
          break;
        case 'curve':
          final path = Path()
            ..moveTo(item.x, item.y)
            ..quadraticBezierTo(item.cx, item.cy, item.x2, item.y2);
          canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.50)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          break;
        case 'line':
          canvas.drawLine(
            Offset(item.x, item.y), Offset(item.x2, item.y2),
            Paint()
              ..color = color
              ..strokeWidth = 2,
          );
          break;
        case 'label':
          _drawText(
            canvas, item.text, item.x, item.y,
            item.color.isNotEmpty ? color : colorScheme.onSurface,
            14,
          );
          break;
        case 'outlet':
          // Drawn as a real accessible Icon widget above the canvas.
          break;
      }
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y,
      Color color, double size, {bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 480);
    painter.paint(
      canvas,
      Offset(center ? x - painter.width / 2 : x,
          center ? y - painter.height / 2 : y),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomElementsPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.colorScheme != colorScheme;
}
