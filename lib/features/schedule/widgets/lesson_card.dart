import 'package:flutter/material.dart';

import '../data/lesson_kind.dart';

/// Reference-style timetable card. All actions still use the original lesson
/// identity; only presentation changes.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.time,
    required this.subject,
    required this.type,
    required this.room,
    required this.teacher,
    this.onTap,
    this.footer,
    this.onBookSeat,
    this.attendanceAbsent = false,
  });

  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;
  final VoidCallback? onTap;
  final Widget? footer;
  final VoidCallback? onBookSeat;
  final bool attendanceAbsent;

  (String, String) _hours() {
    final times = RegExp(r'\d{1,2}:\d{2}')
        .allMatches(time)
        .map((match) => match.group(0)!)
        .toList();
    if (times.length >= 2) return (times[0], times[1]);
    if (times.length == 1) return (times[0], '');
    return (time, '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kind = lessonKind(type, subject: subject);
    final accent = lessonKindColor(kind);
    final (start, end) = _hours();
    final shortType = switch (kind) {
      LessonKind.lecture => 'ЛЕК',
      LessonKind.practice => 'ПРАК',
      LessonKind.laboratory => 'ЛАБ',
      LessonKind.elective => 'ФАК',
      LessonKind.other => lessonKindLabel(type, subject: subject)
          .toUpperCase(),
    };
    final typeIcon = switch (kind) {
      LessonKind.practice => Icons.edit_outlined,
      LessonKind.laboratory => Icons.science_outlined,
      LessonKind.lecture => Icons.menu_book_outlined,
      _ => Icons.class_outlined,
    };
    final muted = scheme.onSurfaceVariant;
    final textColor = scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF151416)
                  : const Color(0xFFF8F7FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: dark ? const Color(0xFF302E33)
                    : const Color(0xFFE1DFE7),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(start,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(end,
                                  style: TextStyle(
                                    color: muted, fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.isEmpty ? 'Занятие' : subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    height: 1.19,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.19),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(typeIcon, color: accent, size: 14),
                                      const SizedBox(width: 5),
                                      Text(shortType,
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (attendanceAbsent) ...[
                                  const SizedBox(height: 7),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      key: const ValueKey('schedule-absence-n'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(9),
                                        color: scheme.primary.withOpacity(0.18),
                                      ),
                                      child: Text('Н', style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w900,
                                      )),
                                    ),
                                  ),
                                ],
                                if (room.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Icon(Icons.location_on_outlined,
                                      size: 15, color: muted),
                                    const SizedBox(width: 5),
                                    Expanded(child: Text(room,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                    )),
                                  ]),
                                ],
                                if (onBookSeat != null) ...[
                                  TextButton.icon(
                                    key: const ValueKey('schedule-book-seat'),
                                    onPressed: onBookSeat,
                                    icon: const Icon(
                                      Icons.event_seat_outlined, size: 16),
                                    label: const Text('Выбрать место'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                      minimumSize: const Size(0, 34),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: scheme.primary,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                if (teacher.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Row(children: [
                                    Icon(Icons.people_outline,
                                      size: 15, color: muted),
                                    const SizedBox(width: 5),
                                    Expanded(child: Text(teacher,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: muted, fontSize: 13,
                                      ),
                                    )),
                                  ]),
                                ],
                                if (footer != null) footer!,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
