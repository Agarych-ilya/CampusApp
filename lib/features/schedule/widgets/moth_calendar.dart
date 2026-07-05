import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';

// Маленькое всплывающее окно календаря месяца.
class MonthCalendarPopup extends StatefulWidget {
  const MonthCalendarPopup({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<MonthCalendarPopup> createState() => _MonthCalendarPopupState();
}

class _MonthCalendarPopupState extends State<MonthCalendarPopup> {
  // Месяц, который сейчас открыт в календаре.
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();

    _visibleMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  // Перейти на предыдущий месяц.
  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  // Перейти на следующий месяц.
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
          // Верхняя строка календаря: стрелки и месяц.
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

          // Названия дней недели в календаре.
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

          // Сетка календаря 7 колонок × 6 строк.
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

  // Находит первый день, который должен отображаться в сетке календаря.
  // Обычно это понедельник перед первым числом месяца.
  DateTime _getFirstCalendarDate() {
    final firstMonthDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);

    return firstMonthDay.subtract(Duration(days: firstMonthDay.weekday - 1));
  }

  // Заголовок календаря: "Июнь 2026".
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

// Маленькая подпись дня недели в календаре месяца.
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

