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
  /// Compact booking link beside the room, only for eligible M-307 lessons.
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
                    key: const ValueKey('schedule-book-m307'),
                    onPressed: onBookSeat,
                    icon: const Icon(Icons.event_seat_outlined, size: 16),
                    label: const Text('Выбрать место'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.brightness == Brightness.dark
                          ? const Color(0xFFAFCBFA)
                          : const Color(0xFF365E92),
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
          if (footer != null) footer!,
        ],
      ),
      ),
    );
  }
}
