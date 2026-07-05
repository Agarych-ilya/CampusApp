import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';


// Горизонтальная строка с днями недели.
// Показывает 7 дней: пн, вт, ср, чт, пт, сб, вс.
class WeekDaysRow extends StatelessWidget {
  const WeekDaysRow({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    // Находим понедельник текущей недели.
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

  // Локальная функция сравнения дат.
  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }
}

// Один элемент строки недели:
// например "пн" и число "1".
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

            // Кружок с числом дня.
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
