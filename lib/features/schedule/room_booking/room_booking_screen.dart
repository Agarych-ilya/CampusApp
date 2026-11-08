import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../data/schedule_lesson.dart';
import 'room_booking_api.dart';

/// Seat numbers count outwards from the central aisle in V-308.
/// Each lesson has its own date/slot taken from the schedule card.
class RoomBookingScreen extends StatefulWidget {
  const RoomBookingScreen({
    super.key,
    required this.lesson,
    required this.room,
    required this.slot,
  });

  final ScheduleLesson lesson;
  final String room;
  final String slot;

  @override
  State<RoomBookingScreen> createState() => _RoomBookingScreenState();
}

class _RoomBookingScreenState extends State<RoomBookingScreen> {
  final RoomBookingApi _api = const RoomBookingApi();
  final ScrollController _horizontalController =
      ScrollController(initialScrollOffset: 165);
  late final String _date;
  RoomAvailability? _availability;
  RoomSeat? _selected;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = RoomBookingApi.dateIso(widget.lesson.parsedDate!);
    _reload();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  String get _cleanRoom => widget.room;

  String get _lessonCaption =>
      '${widget.lesson.date} · ${widget.lesson.time} · $_cleanRoom';

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.load(
        room: widget.room,
        date: _date,
        slot: widget.slot,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _reserve() async {
    final seat = _selected;
    if (_saving || seat == null || _availability?.mine != null) return;
    setState(() => _saving = true);
    try {
      final result = await _api.reserve(
        room: widget.room,
        date: _date,
        slot: widget.slot,
        seat: seat,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
      });
      _message('Место забронировано');
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', ''));
      // A second student may have taken the seat meanwhile.
      await _reload();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_saving || _availability?.mine == null) return;
    setState(() => _saving = true);
    try {
      final result = await _api.cancel(
        room: widget.room,
        date: _date,
        slot: widget.slot,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
      });
      _message('Бронирование отменено');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _seat(RoomSeat seat, Map<String, RoomSeat> occupied,
      {double arcOffset = 0}) {
    final booked = occupied[seat.key];
    final isMine = booked?.mine == true;
    final isTaken = booked != null && !isMine;
    final isSelected = _selected?.key == seat.key;
    final blocked = _saving || isTaken || _availability?.mine != null;

    final color = isMine
        ? const Color(0xFFB6E8CA)
        : isTaken
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : isSelected
                ? AppTheme.pink
                : Theme.of(context).colorScheme.surface;
    final borderColor = isSelected
        ? AppTheme.pink
        : isMine
            ? const Color(0xFF27915C)
            : Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Transform.translate(
        offset: Offset(0, arcOffset),
        child: Tooltip(
          message: 'Ряд ${seat.row}, ${widget.room == 'В-308' ? (seat.desk == 1 ? 'слева' : 'справа') : 'парта ${seat.desk}'}, место ${seat.seat}'
              '${isMine ? ' · моё место' : isTaken ? ' · занято' : ''}',
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: blocked
                ? null
                : () => setState(() => _selected = seat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 27,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              ),
              child: isMine
                  ? const Icon(Icons.check, size: 17, color: Color(0xFF176039))
                  : Text(
                      '${seat.seat}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : isTaken
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _v308Row(int row, Map<String, RoomSeat> occupied) {
    final count = row <= 4 ? 10 : 8;
    final missing = 10 - count;
    Widget half(int sector) {
      final seatNumbers = sector == 1
          ? List<int>.generate(count, (index) => count - index)
          : List<int>.generate(count, (index) => index + 1);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sector == 1) SizedBox(width: missing * 31),
          for (final seatNumber in seatNumbers)
            _seat(
              RoomSeat(row, sector, seatNumber),
              occupied,
              arcOffset: (seatNumber - (count + 1) / 2).abs() * 1.25,
            ),
          if (sector == 2) SizedBox(width: missing * 31),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(1),
          Container(
            width: 70,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              'Ряд $row',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          half(2),
        ],
      ),
    );
  }

  Widget _v308SectionLabel(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 21,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _v308Layout(Map<String, RoomSeat> occupied) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ЗАДНЯЯ ЧАСТЬ АУДИТОРИИ',
            style: TextStyle(fontSize: 11, letterSpacing: 1.1)),
        _v308SectionLabel(
          'Верхние 4 ряда · 10 мест с каждой стороны',
          const Color(0xFFE57878),
        ),
        for (var row = 1; row <= 4; row++) _v308Row(row, occupied),
        _v308SectionLabel(
          'Нижние 6 рядов · 8 мест с каждой стороны',
          const Color(0xFF628AE6),
        ),
        for (var row = 5; row <= 10; row++) _v308Row(row, occupied),
        const SizedBox(height: 22),
        Container(
          width: 330,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('ПРЕПОДАВАТЕЛЬ / ЭКРАН',
              style: TextStyle(fontSize: 11, letterSpacing: 0.8)),
        ),
      ],
    );
  }

  Widget _m307Layout(Map<String, RoomSeat> occupied) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Ряды идут от входа к преподавателю',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 1; row <= 3; row++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Column(
                  children: [
                    Text('Ряд $row',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (var desk = 1; desk <= 9; desk++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _seat(RoomSeat(row, desk, 1), occupied),
                                _seat(RoomSeat(row, desk, 2), occupied),
                              ],
                            ),
                            Text('Парта $desk',
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('ПРЕПОДАВАТЕЛЬ / ЭКРАН',
            style: TextStyle(fontSize: 11, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 13,
            width: 13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = _availability;
    final occupied = <String, RoomSeat>{
      if (availability != null)
        for (final seat in availability.occupied) seat.key: seat,
    };
    final mine = availability?.mine;

    return Scaffold(
      appBar: AppBar(
        title: Text('Выбор места · ${widget.room}'),
        actions: [
          IconButton(
            tooltip: 'Обновить занятые места',
            onPressed: _saving ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.lesson.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 5),
              Text(_lessonCaption, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (availability != null)
                Text(
                  'Свободно ${availability.available} из ${availability.capacity} мест',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  _legendItem(theme.colorScheme.surface, 'Свободно'),
                  _legendItem(theme.colorScheme.surfaceContainerHighest, 'Занято'),
                  _legendItem(AppTheme.pink, 'Выбрано'),
                  _legendItem(const Color(0xFFB6E8CA), 'Моё'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Схему можно прокручивать в стороны и по вертикали.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _reload,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: widget.room == 'В-308'
                                      ? _v308Layout(occupied)
                                      : _m307Layout(occupied),
                                ),
                              ),
                            ),
                          ),
              ),
              const SizedBox(height: 10),
              if (mine != null) ...[
                Text(
                  widget.room == 'В-308'
                      ? 'Твоё место: ряд ${mine.row}, ${mine.desk == 1 ? 'слева' : 'справа'}, место ${mine.seat}'
                      : 'Твоё место: ряд ${mine.row}, парта ${mine.desk}, место ${mine.seat}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _cancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Отменить бронь'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selected == null || _saving ? null : _reserve,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_seat_outlined),
                    label: Text(_selected == null
                        ? 'Выбери свободное место'
                        : 'Забронировать выбранное место'),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Тестовое бронирование CampusApp, не официальная бронь МЭИ.',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
