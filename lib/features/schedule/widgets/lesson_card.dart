import 'package:flutter/material.dart';

import '../data/lesson_kind.dart';
import 'lesson_live_progress.dart';

/// A timetable lesson. An absence marker belongs to the subject row,
/// below the lesson type, and never overlaps the room's seat-booking action.
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
    this.lessonDate,
  });

  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;
  final DateTime? lessonDate;
  final VoidCallback? onTap;
  final Widget? footer;
  final VoidCallback? onBookSeat;

  /// Only the current BARS-authenticated student's confirmed absence.
  final bool attendanceAbsent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = lessonKind(type, subject: subject);
    final accent = lessonKindColor(kind);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.58),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  time.isEmpty ? 'Время не указано' : time,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonKindLabel(type, subject: subject),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject.isEmpty ? 'Занятие' : subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      height: 1.24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (attendanceAbsent) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      label: 'Пропуск занятия',
                      child: Container(
                        key: const ValueKey('schedule-absence-n'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.20),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.50)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Н',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (room.isNotEmpty || onBookSeat != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (onBookSeat != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const ValueKey('schedule-book-seat'),
                      onPressed: onBookSeat,
                      icon: const Icon(Icons.event_seat_outlined, size: 16),
                      label: const Text('Выбрать место'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (teacher.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                teacher,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
            if (lessonDate != null)
              LessonLiveProgress(
                lessonDate: lessonDate!,
                time: time,
              ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
