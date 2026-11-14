import 'package:flutter/material.dart';

import '../data/schedule_lesson.dart';
import '../data/lesson_kind.dart';

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

    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 99,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          final weekend = index >= 5;
          final ink = selected
              ? const Color(0xFF1A1330)
              : weekend
                  ? scheme.onSurfaceVariant.withOpacity(0.58)
                  : scheme.onSurface;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Semantics(
                label: '${_weekDays[index]}, ${day.day}, пар: ${lessons.length}',
                button: true,
                selected: selected,
                child: InkWell(
                  key: ValueKey('schedule-day-${day.year}-${day.month}-${day.day}'),
                  onTap: () => onDateSelected(day),
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : dark
                              ? const Color(0xFF16151A)
                              : const Color(0xFFF0EEF5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekDays[index].toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const Spacer(),
                        if (lessons.isEmpty)
                          const SizedBox(height: 6)
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              for (var i = 0; i < lessons.length && i < 5; i++)
                                Container(
                                  key: ValueKey('lesson-dot-${day.year}-${day.month}-${day.day}-$i'),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF312255)
                                        : lessonKindColor(lessonKind(
                                            lessons[i].type,
                                            subject: lessons[i].subject,
                                          )),
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
            ),
          );
        }),
      ),
    );
  }
}
