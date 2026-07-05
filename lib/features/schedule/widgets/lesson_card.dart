import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';

// Карточка одного занятия.
class LessonCard extends StatelessWidget {
  const LessonCard({
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Вертикальная розовая полоска слева у карточки.
          Container(
            width: 4,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.pink,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Время занятия.
                Text(
                  time.isEmpty ? 'Время не указано' : time,
                  style: const TextStyle(
                    color: AppTheme.pink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                // Название предмета.
                Text(
                  subject.isEmpty ? 'Занятие' : subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                // Тип занятия и аудитория.
                Text(_formatLessonInfo(), style: theme.textTheme.bodyMedium),

                // Преподаватель показывается только если он есть.
                if (teacher.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    teacher,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Собирает строку вида:
  // "Экзамен • М-307 (Корпус М)".
  String _formatLessonInfo() {
    final parts = [if (type.isNotEmpty) type, if (room.isNotEmpty) room];

    if (parts.isEmpty) {
      return 'Информация уточняется';
    }

    return parts.join(' • ');
  }
}
