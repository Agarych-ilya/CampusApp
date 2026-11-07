import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import '/core/theme/app_theme.dart';
import '../data/data.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleApi _scheduleApi = ScheduleApi();
  final GroupStorage _groupStorage = GroupStorage();

  String? _groupName;

  bool _isInitializing = true;

  String? _initializationError;

  late DateTime _selectedDate;

  late Future<List<ScheduleLesson>> _weekLessonsFuture;

  @override
  void initState() {
    super.initState();

    _selectedDate = DateTime.now();

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      var group = await _groupStorage.getGroup();

      if (group == null || group.isEmpty) {
        throw StateError(
          'Учебная группа не найдена. '
          'Войди в CampusApp через БАРС, чтобы загрузить свою группу.',
        );
      }

      _groupName = group;

      _weekLessonsFuture = _loadWeekLessons();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializationError = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<List<ScheduleLesson>> _loadWeekLessons({bool forceRefresh = false}) {
    final group = _groupName;

    if (group == null || group.isEmpty) {
      throw StateError('Группа пользователя не определена');
    }

    return _scheduleApi.getWeekSchedule(
      group: group,
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
    if (_groupName == null) {
      return;
    }

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
          child: MonthCalendarPopup(
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

    if (_isInitializing) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator(color: AppTheme.pink)),
      );
    }

    if (_initializationError != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Не удалось загрузить данные пользователя',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_initializationError!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _initializationError = null;
                    });

                    _initialize();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

            WeekDaysRow(
              selectedDate: _selectedDate,
              onDateSelected: _selectDate,
            ),

            const SizedBox(height: 20),

            Text(
              _groupName ?? '',
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
                    return ScheduleMessage(
                      icon: Icons.error_outline,
                      title: 'Не удалось загрузить расписание',
                      subtitle: snapshot.error?.toString() ??
                          'Проверь соединение с сервером',
                      buttonText: 'Повторить',
                      onPressed: _refreshWeekSchedule,
                    );
                  }

                  final weekLessons = snapshot.data ?? [];

                  final dayLessons = _filterLessonsBySelectedDate(weekLessons);

                  if (dayLessons.isEmpty) {
                    return const ScheduleMessage(
                      icon: Icons.event_busy_outlined,
                      title: 'Занятий нет',
                      subtitle: 'Для выбранного дня расписание не найдено',
                    );
                  }

                  return Column(
                    children: [
                      if (_scheduleApi.showingOfflineCopy)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Нет связи с сервером. '
                                  'Показано сохранённое расписание.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: dayLessons.length,
                          itemBuilder: (context, index) {
                            final lesson = dayLessons[index];

                            return LessonCard(
                              time: lesson.time,
                              subject: lesson.subject,
                              type: lesson.type,
                              room: lesson.room,
                              teacher: lesson.teacher,
                            );
                          },
                        ),
                      ),
                    ],
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
    const weekDays = [
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
    const months = [
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
    const months = [
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


