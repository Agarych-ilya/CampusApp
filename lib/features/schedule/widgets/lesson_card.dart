import 'package:flutter/material.dart';

import '../data/lesson_kind.dart';

/// Schedule card with a color-coded lesson type next to its time.
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
  });

  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;
  final VoidCallback? onTap;
  final Widget? footer;
  /// A prominent one-tap entry, shown only for eligible M-307 lessons.
  final VoidCallback? onBookSeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = lessonKind(type, subject: subject);
    final accent = lessonKindColor(kind);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                time.isEmpty ? 'Время не указано' : time,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subject.isEmpty ? 'Занятие' : subject,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (room.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(room, style: theme.textTheme.bodyMedium),
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
          if (onBookSeat != null) ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('schedule-book-m307'),
                onPressed: onBookSeat,
                icon: const Icon(Icons.event_seat_outlined, size: 19),
                label: const Text('Забронировать место · М-307'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFAFCBFA),
                  foregroundColor: const Color(0xFF192A41),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (footer != null) footer!,
        ],
      ),
      ),
    );
  }
}
