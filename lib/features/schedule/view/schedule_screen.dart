import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import '/core/theme/app_theme.dart';
import '../data/data.dart';

// Экран расписания.
// Здесь отображается выбранная неделя, выбранный день и список занятий на этот день.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // API-класс, через который экран получает расписание.
  final ScheduleApi _scheduleApi = ScheduleApi();

  // Пока группа задана вручную.
  // Позже можно будет брать её из профиля пользователя или настроек.
  static const String _groupName = 'А-03-23';

  // Текущая выбранная дата.
  late DateTime _selectedDate;

  // Future с расписанием на всю выбранную неделю.
  // Важно: здесь хранится именно неделя, а не один день.
  late Future<List<ScheduleLesson>> _weekLessonsFuture;

  @override
  void initState() {
    super.initState();

    // При открытии экрана выбираем сегодняшнюю дату.
    _selectedDate = DateTime.now();

    // Загружаем расписание на неделю, в которую входит выбранная дата.
    _weekLessonsFuture = _loadWeekLessons();
  }

  // Загружает расписание на всю неделю.
  // forceRefresh = true нужен, чтобы принудительно обновить кэш.
  Future<List<ScheduleLesson>> _loadWeekLessons({bool forceRefresh = false}) {
    return _scheduleApi.getWeekSchedule(
      group: _groupName,
      selectedDate: _selectedDate,
      forceRefresh: forceRefresh,
    );
  }

  // Выбор даты.
  // Если пользователь нажал на другой день той же недели,
  // новый запрос на сервер не делаем — просто фильтруем уже загруженную неделю.
  //
  // Если пользователь выбрал дату из другой недели,
  // загружаем новую неделю.
  void _selectDate(DateTime date) {
    final oldWeekStart = _getWeekStart(_selectedDate);
    final newWeekStart = _getWeekStart(date);

    setState(() {
      _selectedDate = date;

      // Если неделя изменилась, загружаем расписание новой недели.
      if (!_isSameDate(oldWeekStart, newWeekStart)) {
        _weekLessonsFuture = _loadWeekLessons();
      }
    });
  }

  // Принудительно обновляет расписание выбранной недели.
  // Используется по кнопке обновления справа сверху.
  void _refreshWeekSchedule() {
    setState(() {
      _weekLessonsFuture = _loadWeekLessons(forceRefresh: true);
    });
  }

  // Показывает маленький календарь месяца.
  // Через него можно выбрать любую дату.
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

  // Возвращает понедельник недели, в которую входит переданная дата.
  DateTime _getWeekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  // Сравнение двух дат без учёта времени.
  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  // Преобразует дату занятия из строки формата "01.06.2026" в DateTime.
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

  // Фильтрует расписание всей недели и оставляет только занятия выбранного дня.
  //
  // Например:
  // сервер вернул всю неделю: 01.06, 02.06, 06.06
  // пользователь выбрал 02.06
  // здесь останутся только занятия за 02.06.
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

    // Сортируем занятия выбранного дня по времени.
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

            // Верхняя строка:
            // слева день недели, справа месяц и кнопка обновления.
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

                    // Кнопка принудительного обновления расписания недели.
                    IconButton(
                      onPressed: _refreshWeekSchedule,
                      icon: const Icon(Icons.refresh, size: 21),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Строка дней текущей недели.
            WeekDaysRow(
              selectedDate: _selectedDate,
              onDateSelected: _selectDate,
            ),

            const SizedBox(height: 20),

            // Название группы.
            Text(
              _groupName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            // Выбранная дата текстом.
            Text(
              _formatSelectedDate(_selectedDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 14),

            // Основная область расписания.
            Expanded(
              child: FutureBuilder<List<ScheduleLesson>>(
                future: _weekLessonsFuture,
                builder: (context, snapshot) {
                  // Пока расписание загружается.
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.pink),
                    );
                  }

                  // Если при загрузке произошла ошибка.
                  if (snapshot.hasError) {
                    return ScheduleMessage(
                      icon: Icons.error_outline,
                      title: 'Не удалось загрузить расписание',
                      subtitle: 'Проверь, что backend запущен на порту 8000',
                      buttonText: 'Повторить',
                      onPressed: _refreshWeekSchedule,
                    );
                  }

                  // Это расписание всей недели.
                  final weekLessons = snapshot.data ?? [];

                  // А это уже только занятия выбранного дня.
                  final dayLessons = _filterLessonsBySelectedDate(weekLessons);

                  // Если в выбранный день занятий нет.
                  if (dayLessons.isEmpty) {
                    return const ScheduleMessage(
                      icon: Icons.event_busy_outlined,
                      title: 'Занятий нет',
                      subtitle: 'Для выбранного дня расписание не найдено',
                    );
                  }

                  // Список карточек занятий выбранного дня.
                  return ListView.builder(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Название дня недели для верхней строки.
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

  // Название месяца для верхней строки.
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

  // Дата под названием группы.
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







