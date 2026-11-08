import 'package:flutter/material.dart';

import '../data/schedule_lesson.dart';
import '../data/lesson_kind.dart';
import '/core/theme/app_theme.dart';

/// Seven days of the selected week. One coloured dot = one real lesson.
class WeekDaysRow extends StatelessWidget {
  const WeekDaysRow({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.weekLessons = const [],
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<ScheduleLesson> weekLessons;

  static const _weekDays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - selectedDate.weekday + 1,
    );
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        final day = DateTime(monday.year, monday.month, monday.day + index);
        final lessons = weekLessons.where((lesson) {
          final parsed = lesson.parsedDate;
          return parsed != null &&
              parsed.year == day.year &&
              parsed.month == day.month &&
              parsed.day == day.day;
        }).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
        final selected = day.year == selectedDate.year &&
            day.month == selectedDate.month &&
            day.day == selectedDate.day;

        return Expanded(
          child: Semantics(
            label: '${_weekDays[index]}, ${day.day}, пар: ${lessons.length}',
            button: true,
            selected: selected,
            child: InkWell(
              key: ValueKey('schedule-day-${day.year}-${day.month}-${day.day}'),
              onTap: () => onDateSelected(day),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekDays[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withOpacity(0.78),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 31,
                      height: 31,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.pink : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // At most four dots per row on narrow phones.
                    if (lessons.isEmpty)
                      const SizedBox(height: 6)
                    else
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        runSpacing: 3,
                        children: [
                          for (var i = 0; i < lessons.length; i++)
                            Container(
                              key: ValueKey('lesson-dot-${day.year}-${day.month}-${day.day}-$i'),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: lessonKindColor(
                                  lessonKind(lessons[i].type),
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
