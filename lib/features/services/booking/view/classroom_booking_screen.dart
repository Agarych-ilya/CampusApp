import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';
import '../data/classroom_booking_api.dart';
import 'classroom_seat_map.dart';

/// Demonstration booking only; not an official university room reservation.
class ClassroomBookingScreen extends StatefulWidget {
  const ClassroomBookingScreen({
    super.key,
    this.api,
    this.initialDate,
    this.initialSlot,
    this.lessonTime,
  });

  final ClassroomBookingApi? api;
  final DateTime? initialDate;
  final String? initialSlot;
  final String? lessonTime;

  @override
  State<ClassroomBookingScreen> createState() => _ClassroomBookingScreenState();
}

class _ClassroomBookingScreenState extends State<ClassroomBookingScreen> {
  late final ClassroomBookingApi _api;
  late DateTime _date;
  late String _slot;
  bool _dateAdjusted = false;
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
    final lessonDate = widget.initialDate;
    final normalized = lessonDate == null
        ? today
        : DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    final last = today.add(const Duration(days: 60));
    _dateAdjusted = normalized.isBefore(today) || normalized.isAfter(last);
    _date = _dateAdjusted ? today : normalized;
    _slot = classroomDemoSlots.any((slot) => slot.id == widget.initialSlot)
        ? widget.initialSlot!
        : '1';
    _load();
  }

  @override
  void dispose() {
    _requestId++;
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    final date = _date;
    final slot = _slot;
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      final data = await _api.load(date: date, slot: slot);
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

  Future<void> _chooseDate() async {
    if (_working) return;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final last = start.add(const Duration(days: 60));
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(start) ? start : _date,
      firstDate: start,
      lastDate: last,
      helpText: 'Дата бронирования М-307',
    );
    if (!mounted || chosen == null) return;
    if (ClassroomBookingApi.dateKey(chosen) ==
        ClassroomBookingApi.dateKey(_date)) return;
    setState(() => _date = chosen);
    await _load();
  }

  void _chooseSlot(String slot) {
    if (_working || slot == _slot) return;
    setState(() => _slot = slot);
    _load();
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
    if (_working || seat == null || _availability?.mine != null) return;
    final date = _date;
    final slot = _slot;
    final accepted = await _confirm(
      'Подтвердить место?',
      '${seat.label}\nАудитория М-307 · ${_formatDate(date)}\n'
          '${_time(slot)}\n\nЭто тестовая бронь CampusApp.',
      'Забронировать',
    );
    if (!mounted || !accepted) return;
    setState(() => _working = true);
    try {
      final result = await _api.reserve(date: date, slot: slot, seat: seat);
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selected = null;
      });
      _notify('Место забронировано: ${seat.label}');
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
    if (_working || _availability?.mine == null) return;
    final date = _date;
    final slot = _slot;
    final accepted = await _confirm(
      'Отменить бронирование?',
      'Твоё место снова станет доступно другим студентам.',
      'Отменить бронь',
    );
    if (!mounted || !accepted) return;
    setState(() => _working = true);
    try {
      final result = await _api.cancel(date: date, slot: slot);
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
                            Text('М-307',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 3),
                            Text('3 ряда · 9 парт в ряду · 2 места за партой',
                                style: TextStyle(color: muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('54 посадочных места',
                                style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_dateAdjusted || (widget.lessonTime != null &&
                    classroomSlotForLessonTime(widget.lessonTime!) == null)) ...[
                  Text(
                    _dateAdjusted
                        ? 'Дата выбранной пары вне периода бронирования. '
                          'Установлена сегодняшняя дата — проверь её перед подтверждением.'
                        : 'Время выбранной пары не совпадает с тестовыми интервалами. '
                          'Выбери нужный интервал вручную.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Тестовое бронирование внутри CampusApp. '
                  'Оно не подтверждает реальную доступность аудитории '
                  'и не является разрешением МЭИ на её использование.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 22),
                Text('Дата', style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('booking-date'),
                  onPressed: _working ? null : _chooseDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_formatDate(_date)),
                ),
                const SizedBox(height: 18),
                Text('Учебный интервал', style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    for (final slot in snapshot?.slots ?? classroomDemoSlots)
                      ChoiceChip(
                        key: ValueKey('booking-slot-${slot.id}'),
                        label: Text(slot.time),
                        selected: _slot == slot.id,
                        onSelected: _working
                            ? null
                            : (_) => _chooseSlot(slot.id),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_loading)
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
                      Text('Свободно: ${snapshot.available}/54',
                          key: const ValueKey('booking-free-count'),
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                            child: Text('Твоя бронь: ${mine.label}',
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
                        child: Text('Выбрано: ${_selected!.label}',
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
                    'Одно место на студента для выбранной даты и интервала. '
                    'Для другой пары или даты можно выбрать другое место. '
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
