import 'package:flutter/material.dart';

import '../data/own_lesson_note_preview_storage.dart';
import '../data/schedule_lesson.dart';

/// This is visible only for the current student's own timetable.
class LessonNotePreview extends StatefulWidget {
  const LessonNotePreview({
    super.key,
    required this.group,
    required this.lesson,
    this.revision = 0,
  });

  final String group;
  final ScheduleLesson lesson;
  final int revision;

  @override
  State<LessonNotePreview> createState() => _LessonNotePreviewState();
}

class _LessonNotePreviewState extends State<LessonNotePreview> {
  final _storage = OwnLessonNotePreviewStorage();
  late Future<OwnLessonNotePreview> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant LessonNotePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.group != widget.group ||
        oldWidget.lesson.date != widget.lesson.date ||
        oldWidget.lesson.time != widget.lesson.time ||
        oldWidget.lesson.subject != widget.lesson.subject) {
      _reload();
    }
  }

  void _reload() {
    _data = _storage.load(
      group: widget.group,
      lesson: widget.lesson,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<OwnLessonNotePreview>(
      future: _data,
      builder: (context, snapshot) {
        final note = snapshot.data;
        if (note == null || note.isEmpty) {
          return const SizedBox.shrink();
        }
        final items = <({String label, String value, IconData icon})>[
          if (note.personal.isNotEmpty)
            (label: 'Личная', value: note.personal,
                icon: Icons.lock_outline_rounded),
          if (note.published.isNotEmpty)
            (label: 'Для группы', value: note.published,
                icon: Icons.groups_outlined),
        ];
        return Padding(
          key: const ValueKey('lesson-note-preview'),
          padding: const EdgeInsets.only(top: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.55),
              ),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${item.label}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: item.value),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
