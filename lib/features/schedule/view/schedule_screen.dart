import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../data/schedule_api.dart';
import '../data/schedule_lesson.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleApi _scheduleApi = ScheduleApi();

  static const String _groupName = 'А-03-23';

  late DateTime _selectedDate;
  late Future<List<ScheduleLesson>> _weekLessonsFuture;

  @override
  void initState() {
    super.initState();

    _selectedDate = DateTime.now();
    _weekLessonsFuture = _loadWeekLessons();
  }

  Future<List<ScheduleLesson>> _loadWeekLessons({bool forceRefresh = false}) {
    return _scheduleApi.getWeekSchedule(
      group: _groupName,
      selectedDate: _selectedDate,
      forceRefresh: forceRefresh,
    );
  }

  void _selectDate(DateTime date) {
    final oldWeekStart = _getWeekStart(_selectedDate);
    final newWeekStart = _getWeekStart(date);

    setState(() {
      _selectedDate = date;

      if (!_isSameDate(oldWeekStart, newWeekStart)) {
        _weekLessonsFuture = _loadWeekLessons();
      }
    });
  }

  void _refreshWeekSchedule() {
    setState(() {
      _weekLessonsFuture = _loadWeekLessons(forceRefresh: true);
    });
  }

  Future<void> _showMonthCalendar() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.topLeft,
          insetPadding: EdgeInsets.only(
            left: 20,
            top: MediaQuery.of(dialogContext).padding.top + 52,
            right: 20,
            bottom: 24,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: _MonthCalendarPopup(
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              _selectDate(date);
              Navigator.of(dialogContext).pop();
            },
          ),
        );
      },
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  DateTime? _parseLessonDate(String date) {
    final match = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(date);

    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);

    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  List<ScheduleLesson> _filterLessonsBySelectedDate(
    List<ScheduleLesson> weekLessons,
  ) {
    final filteredLessons = weekLessons.where((lesson) {
      final lessonDate = _parseLessonDate(lesson.date);

      if (lessonDate == null) {
        return false;
      }

      return _isSameDate(lessonDate, _selectedDate);
    }).toList();

    filteredLessons.sort((firstLesson, secondLesson) {
      return firstLesson.time.compareTo(secondLesson.time);
    });

    return filteredLessons;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showMonthCalendar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getWeekDayName(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: [
                    Text(
                      _getMonthName(_selectedDate),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _refreshWeekSchedule,
                      icon: const Icon(Icons.refresh, size: 21),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            _WeekDaysRow(
              selectedDate: _selectedDate,
              onDateSelected: _selectDate,
            ),

            const SizedBox(height: 20),

            Text(
              _groupName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _formatSelectedDate(_selectedDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: FutureBuilder<List<ScheduleLesson>>(
                future: _weekLessonsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.pink),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ScheduleMessage(
                      icon: Icons.error_outline,
                      title: 'Не удалось загрузить расписание',
                      subtitle: 'Проверь, что backend запущен на порту 8000',
                      buttonText: 'Повторить',
                      onPressed: _refreshWeekSchedule,
                    );
                  }

                  final weekLessons = snapshot.data ?? [];

                  final dayLessons = _filterLessonsBySelectedDate(weekLessons);

                  if (dayLessons.isEmpty) {
                    return const _ScheduleMessage(
                      icon: Icons.event_busy_outlined,
                      title: 'Занятий нет',
                      subtitle: 'Для выбранного дня расписание не найдено',
                    );
                  }

                  return ListView.builder(
                    itemCount: dayLessons.length,
                    itemBuilder: (context, index) {
                      final lesson = dayLessons[index];

                      return _LessonCard(
                        time: lesson.time,
                        subject: lesson.subject,
                        type: lesson.type,
                        room: lesson.room,
                        teacher: lesson.teacher,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWeekDayName(DateTime date) {
    final weekDays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];

    return weekDays[date.weekday - 1];
  }

  String _getMonthName(DateTime date) {
    final months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return months[date.month - 1];
  }

  String _formatSelectedDate(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }
}

class _WeekDaysRow extends StatelessWidget {
  const _WeekDaysRow({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );

    final weekDays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));

        return _WeekDayItem(
          weekDay: weekDays[index],
          dayNumber: date.day.toString(),
          isSelected: _isSameDate(date, selectedDate),
          onTap: () {
            onDateSelected(date);
          },
        );
      }),
    );
  }

  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }
}

class _WeekDayItem extends StatelessWidget {
  const _WeekDayItem({
    required this.weekDay,
    required this.dayNumber,
    required this.onTap,
    this.isSelected = false,
  });

  final String weekDay;
  final String dayNumber;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 36,
        child: Column(
          children: [
            Text(
              weekDay,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),

            const SizedBox(height: 4),

            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.pink : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  dayNumber,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendarPopup extends StatefulWidget {
  const _MonthCalendarPopup({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_MonthCalendarPopup> createState() => _MonthCalendarPopupState();
}

class _MonthCalendarPopupState extends State<_MonthCalendarPopup> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();

    _visibleMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _showNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstCalendarDate = _getFirstCalendarDate();

    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _showPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),

              Expanded(
                child: Text(
                  _getMonthTitle(_visibleMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),

              IconButton(
                onPressed: _showNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalendarWeekDayText('пн'),
              _CalendarWeekDayText('вт'),
              _CalendarWeekDayText('ср'),
              _CalendarWeekDayText('чт'),
              _CalendarWeekDayText('пт'),
              _CalendarWeekDayText('сб'),
              _CalendarWeekDayText('вс'),
            ],
          ),

          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final date = firstCalendarDate.add(Duration(days: index));

              final isCurrentMonth = date.month == _visibleMonth.month;
              final isSelected = _isSameDate(date, widget.selectedDate);
              final isToday = _isSameDate(date, DateTime.now());

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  widget.onDateSelected(date);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.pink : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: AppTheme.pink.withOpacity(0.5))
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isCurrentMonth
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  DateTime _getFirstCalendarDate() {
    final firstMonthDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);

    return firstMonthDay.subtract(Duration(days: firstMonthDay.weekday - 1));
  }

  String _getMonthTitle(DateTime date) {
    final months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }
}

class _CalendarWeekDayText extends StatelessWidget {
  const _CalendarWeekDayText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.time,
    required this.subject,
    required this.type,
    required this.room,
    required this.teacher,
  });

  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.pink,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time.isEmpty ? 'Время не указано' : time,
                  style: const TextStyle(
                    color: AppTheme.pink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subject.isEmpty ? 'Занятие' : subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(_formatLessonInfo(), style: theme.textTheme.bodyMedium),

                if (teacher.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    teacher,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLessonInfo() {
    final parts = [if (type.isNotEmpty) type, if (room.isNotEmpty) room];

    if (parts.isEmpty) {
      return 'Информация уточняется';
    }

    return parts.join(' • ');
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppTheme.pink),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: onPressed,
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    color: AppTheme.pink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
