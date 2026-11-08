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
  });

  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = lessonKind(type, subject: subject);
    final accent = lessonKindColor(kind);

    return Container(
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
        ],
      ),
    );
  }
}
