import 'package:flutter/material.dart';

import '../data/schedule_lesson.dart';
import '../data/lesson_kind.dart';

enum ScheduleViewMode { day, week, month }

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


/// Screenshot-aligned schedule header, based on the reference application's
/// segmented selector, day pills and compact calendar controls.
class ReferenceScheduleHeader extends StatelessWidget {
  const ReferenceScheduleHeader({
    required this.date,
    required this.weekLessons,
    required this.mode,
    required this.onModeSelected,
    required this.onDateSelected,
    required this.onGroupSearch,
    required this.groupName,
    required this.semesterLabel,
    required this.lessonCount,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final DateTime date;
  final List<ScheduleLesson> weekLessons;
  final ScheduleViewMode mode;
  final ValueChanged<ScheduleViewMode> onModeSelected;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onGroupSearch;
  final String? groupName;
  final String semesterLabel;
  final int lessonCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  static const _weekNames = [
    'Понедельник', 'Вторник', 'Среда', 'Четверг',
    'Пятница', 'Суббота', 'Воскресенье',
  ];
  static const _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель',
    'Май', 'Июнь', 'Июль', 'Август',
    'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = mode == ScheduleViewMode.month
        ? '${_monthNames[date.month - 1]} ${date.year}'
        : '${_weekNames[date.weekday - 1]}, ${date.day}';
    final modes = ScheduleViewMode.values;
    const titles = ['День', 'Неделя', 'Месяц'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('schedule-view-selector'),
          height: 61,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF131216) : const Color(0xFFF0EDF7),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: dark ? const Color(0xFF302D35)
                  : const Color(0xFFE5E1EE),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < modes.length; i++)
                Expanded(
                  child: InkWell(
                    key: ValueKey('schedule-view-${modes[i].name}'),
                    borderRadius: BorderRadius.circular(29),
                    onTap: () => onModeSelected(modes[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 190),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: mode == modes[i]
                            ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: Text(
                        titles[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: mode == modes[i]
                              ? const Color(0xFF211633)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        if (mode != ScheduleViewMode.month) ...[
          WeekDaysRow(
            selectedDate: date,
            weekLessons: weekLessons,
            onDateSelected: onDateSelected,
          ),
          const SizedBox(height: 22),
        ],
        Text(
          title,
          key: const ValueKey('schedule-selected-date-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.85,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              key: const ValueKey('schedule-previous-day'),
              onPressed: onPrevious,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
              ),
              child: Text(mode == ScheduleViewMode.month
                  ? '← мес' : '← нед',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 12),
            TextButton(
              key: const ValueKey('schedule-today'),
              onPressed: () => onDateSelected(DateTime.now()),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
              ),
              child: Text('сегодня', style: TextStyle(
                color: scheme.primary, fontWeight: FontWeight.w800,
              )),
            ),
            const SizedBox(width: 12),
            TextButton(
              key: const ValueKey('schedule-next-day'),
              onPressed: onNext,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
              ),
              child: Text(mode == ScheduleViewMode.month
                  ? 'мес →' : 'нед →',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            const Spacer(),
            if (mode != ScheduleViewMode.month)
              Text('${lessonCount} пары',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
        Row(
          children: [
            Text(
              semesterLabel,
              key: const ValueKey('schedule-semester-week'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withOpacity(0.75),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('schedule-group-search'),
              onPressed: onGroupSearch,
              icon: const Icon(Icons.groups_outlined, size: 15),
              label: Text(groupName ?? 'Группа'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 29),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
