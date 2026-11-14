import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';
import '../data/classroom_booking_api.dart';
import 'classroom_seat_map.dart';
import 'amphitheater_seat_map.dart';
import 'server_room_seat_map.dart';

/// Demonstration booking only; not an official university room reservation.
class ClassroomBookingScreen extends StatefulWidget {
  const ClassroomBookingScreen({
    super.key,
    this.api,
    required this.lessonDate,
    required this.lessonTime,
    this.initialRoom,
    this.allowedRooms,
  });

  final ClassroomBookingApi? api;
  /// Date and time are fixed by the lesson opened from the schedule.
  final DateTime lessonDate;
  final String lessonTime;
  /// Raw room name from the timetable, e.g. "С-401 (Корпус С)".
  final String? initialRoom;
  /// A server-fetched catalogue; old clients retain M-307/V-308 fallback.
  final Set<String>? allowedRooms;

  @override
  State<ClassroomBookingScreen> createState() => _ClassroomBookingScreenState();
}

class _ClassroomBookingScreenState extends State<ClassroomBookingScreen> {
  late final ClassroomBookingApi _api;
  late final DateTime _date;
  late final String? _slot;
  late final String _room;
  String? _unavailableReason;
  ClassroomAvailability? _availability;
  ClassroomSeat? _selected;
  String? _error;
  bool _loading = true;
  bool _working = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ClassroomBookingApi();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _date = DateTime(
      widget.lessonDate.year,
      widget.lessonDate.month,
      widget.lessonDate.day,
    );
    _slot = classroomSlotForLessonTime(widget.lessonTime);
    _room = classroomCodeFromLesson(widget.initialRoom) ?? 'М-307';
    final last = today.add(const Duration(days: 60));
    if (_date.isBefore(today)) {
      _unavailableReason = 'Эта пара уже прошла. Места можно бронировать '
          'только на будущие занятия.';
    } else if (_date.isAfter(last)) {
      _unavailableReason = 'Бронирование доступно не более чем '
          'за 60 дней до занятия.';
    } else if (_slot == null) {
      _unavailableReason = 'Время этой пары не поддерживается тестовой '
          'системой бронирования аудиторий.';
    } else {
      // The chosen lesson is today: don't reserve a seat on a finished lesson.
      final parts = RegExp(r'\d{1,2}:\d{2}')
          .allMatches(widget.lessonTime)
          .map((match) => match.group(0)!)
          .toList();
      if (parts.length >= 2) {
        final finish = parts[1].split(':');
        final ends = DateTime(
          _date.year, _date.month, _date.day,
          int.parse(finish[0]), int.parse(finish[1]),
        );
        if (!ends.isAfter(now)) {
          _unavailableReason = 'Эта пара уже закончилась. '
              'Бронирование недоступно.';
        }
      }
    }
    if (widget.initialRoom != null &&
        !isBookableClassroom(widget.initialRoom) &&
        !(widget.allowedRooms?.contains(_room) ?? false)) {
      _unavailableReason =
          'Для этой аудитории схема бронирования пока не настроена.';
    }
    if (_unavailableReason == null) _load();
  }

  @override
  void dispose() {
    _requestId++;
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    if (_unavailableReason != null || _slot == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _availability = null;
          _selected = null;
          _error = null;
        });
      }
      return;
    }
    final date = _date;
    final slot = _slot!;
    final room = _room;
    setState(() {
      _loading = true;
      _availability = null;
      _error = null;
      _selected = null;
    });
    try {
      final data = await _api.load(date: date, slot: slot, room: room);
      if (!mounted || id != _requestId) return;
      setState(() {
        _availability = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _availability = null;
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _book() async {
    final seat = _selected;
    if (_working || _unavailableReason != null || _slot == null ||
        seat == null || _availability?.mine != null) return;
    final date = _date;
    final slot = _slot!;
    final room = _room;
    final accepted = await _confirm(
      'Подтвердить место?',
      '${_seatLabel(seat)}\nАудитория $room · ${_formatDate(date)}\n'
          '${_time(slot)}\n\nЭто тестовая бронь CampusApp.',
      'Забронировать',
    );
    if (!mounted || !accepted) return;
    setState(() => _working = true);
    try {
      final result = await _api.reserve(
        date: date, slot: slot, room: room, seat: seat,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
      });
      _notify('Место забронировано: ${_seatLabel(seat)}');
    } on ClassroomBookingException catch (error) {
      _notify(error.message);
      if (error.conflict) await _load();
    } catch (error) {
      _notify('Не удалось забронировать место: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    if (_working || _unavailableReason != null || _slot == null ||
        _availability?.mine == null) return;
    final date = _date;
    final slot = _slot!;
    final room = _room;
    final accepted = await _confirm(
      'Отменить бронирование?',
      'Твоё место снова станет доступно другим студентам.',
      'Отменить бронь',
    );
    if (!mounted || !accepted) return;
    setState(() => _working = true);
    try {
      final result = await _api.cancel(
        date: date, slot: slot, room: room,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
      });
      _notify('Бронирование отменено');
    } catch (error) {
      _notify('Не удалось отменить бронь: $error');
      await _load();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _seatLabel(ClassroomSeat seat) =>
      _availability?.layout?.seatLabel(seat.row, seat.desk, seat.seat) ??
      seat.labelForRoom(_room);

  String _time(String slot) {
    final slots = _availability?.slots ?? classroomDemoSlots;
    for (final entry in slots) {
      if (entry.id == slot) return entry.time;
    }
    return '';
  }

  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ServicePalette.theme(Theme.of(context)),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final onSurface = theme.colorScheme.onSurface;
        final muted = theme.colorScheme.onSurfaceVariant;
        final snapshot = _availability;
        final mine = snapshot?.mine;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Бронирование аудиторий'),
            actions: [
              IconButton(
                tooltip: 'Обновить места',
                onPressed: _working ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: ServicePalette.accent.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.meeting_room_outlined,
                            size: 26, color: ServicePalette.accent),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _room,
                              key: const ValueKey('booking-room-label'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              snapshot?.layout?.description ??
                                  (_room == 'В-308'
                                      ? 'Амфитеатр · 4 ряда по 10 и 6 рядов по 8 мест'
                                      : '3 ряда · 9 парт в ряду · 2 места за партой'),
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snapshot != null
                                  ? '${snapshot.capacity} посадочных мест'
                                  : (_room == 'В-308'
                                      ? '176 посадочных мест'
                                      : '54 посадочных места'),
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Тестовое бронирование CampusApp. '
                  'Оно не связано с официальной занятостью '
                  'аудиторий МЭИ.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 20),
                Container(
                  key: const ValueKey('booking-fixed-lesson'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Выбранная пара',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 17),
                          const SizedBox(width: 9),
                          Text(_formatDate(_date)),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 17),
                          const SizedBox(width: 9),
                          Text(widget.lessonTime),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_unavailableReason != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_outlined,
                            color: theme.colorScheme.error, size: 31),
                        const SizedBox(height: 8),
                        Text(
                          'Бронирование недоступно',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _unavailableReason!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  )
                else if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 46),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Column(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: muted, size: 34),
                      const SizedBox(height: 12),
                      Text('Не удалось загрузить места',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 7),
                      Text(_error!, style: TextStyle(color: muted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  )
                else if (snapshot != null) ...[
                  Row(
                    children: [
                      Text('Схема аудитории',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                      const Spacer(),
                      Text('Свободно: ${snapshot.available}/${snapshot.capacity}',
                          key: const ValueKey('booking-free-count'),
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.layout != null)
                    ServerRoomSeatMap(
                      layout: snapshot.layout!,
                      occupied: snapshot.occupied,
                      mine: mine,
                      selected: _selected,
                      disabled: _working,
                      onSelected: (seat) => setState(() => _selected = seat),
                    )
                  else if (_room == 'В-308')
                    AmphitheaterSeatMap(
                      occupied: snapshot.occupied,
                      mine: mine,
                      selected: _selected,
                      disabled: _working,
                      onSelected: (seat) => setState(() => _selected = seat),
                    )
                  else
                    ClassroomSeatMap(
                      occupied: snapshot.occupied,
                      mine: mine,
                      selected: _selected,
                      disabled: _working,
                      onSelected: (seat) => setState(() => _selected = seat),
                    ),
                  const SizedBox(height: 5),
                  if (mine != null) ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: ServicePalette.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: ServicePalette.amber),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text('Твоя бронь: ${_seatLabel(mine)}',
                                style: TextStyle(color: onSurface)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    OutlinedButton.icon(
                      key: const ValueKey('booking-cancel'),
                      onPressed: _working ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Отменить мою бронь'),
                    ),
                  ] else ...[
                    if (_selected != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Text('Выбрано: ${_seatLabel(_selected!)}',
                            style: TextStyle(
                              color: onSurface, fontWeight: FontWeight.w700,
                            )),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('booking-confirm'),
                      onPressed: _working || _selected == null ? null : _book,
                      icon: const Icon(Icons.event_seat_outlined),
                      label: Text(_working
                          ? 'Бронирование…' : 'Забронировать место'),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Text(
                    'Одно место на студента для этой пары. '
                    'Чтобы забронировать место на другое занятие, '
                    'открой его в расписании. '
                    'Занятость обновляется с сервера.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}
