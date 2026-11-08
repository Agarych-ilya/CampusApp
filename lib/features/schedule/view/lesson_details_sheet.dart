import 'package:flutter/material.dart';

import '../data/group_lesson_notes_api.dart';
import '../data/lesson_grades_summary.dart';
import '../data/lesson_kind.dart';
import '../data/private_lesson_notes_storage.dart';
import '../data/schedule_lesson.dart';

/// A bottom-sheet opened from a timetable lesson.
class LessonDetailsSheet extends StatefulWidget {
  const LessonDetailsSheet({
    super.key,
    required this.group,
    required this.lesson,
    required this.scrollController,
  });

  final String group;
  final ScheduleLesson lesson;
  final ScrollController scrollController;

  @override
  State<LessonDetailsSheet> createState() => _LessonDetailsSheetState();
}

class _LessonDetailsSheetState extends State<LessonDetailsSheet> {
  final _personalController = TextEditingController();
  final _sharedController = TextEditingController();
  final _privateStore = PrivateLessonNotesStorage();
  final _notesApi = GroupLessonNotesApi();
  late Future<LessonGradesSummary> _grades;
  late Future<List<GroupLessonNote>> _shared;
  bool _personalLoading = true;
  bool _personalSaving = false;
  bool _sharedSaving = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _grades = LessonGradesSummary.load(widget.lesson.subject);
    _shared = _notesApi.list(widget.group, widget.lesson);
    _loadPersonal();
  }

  @override
  void dispose() {
    _personalController.dispose();
    _sharedController.dispose();
    _notesApi.dispose();
    super.dispose();
  }

  Future<void> _loadPersonal() async {
    try {
      final value = await _privateStore.load(
        group: widget.group,
        lesson: widget.lesson,
      );
      if (!mounted) return;
      _personalController.text = value;
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _personalLoading = false);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _savePersonal() async {
    if (_personalSaving) return;
    setState(() => _personalSaving = true);
    try {
      await _privateStore.save(
        group: widget.group,
        lesson: widget.lesson,
        content: _personalController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Личная заметка сохранена на устройстве')),
      );
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _personalSaving = false);
    }
  }

  Future<void> _publish() async {
    final content = _sharedController.text.trim();
    if (content.isEmpty || _sharedSaving) return;
    setState(() => _sharedSaving = true);
    try {
      await _notesApi.create(widget.group, widget.lesson, content);
      if (!mounted) return;
      _sharedController.clear();
      setState(() {
        _shared = _notesApi.list(widget.group, widget.lesson);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка опубликована для группы')),
      );
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _sharedSaving = false);
    }
  }

  Future<void> _deleteNote(int id) async {
    if (_deleted) return;
    setState(() => _deleted = true);
    try {
      await _notesApi.delete(id);
      if (!mounted) return;
      setState(() {
        _shared = _notesApi.list(widget.group, widget.lesson);
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _deleted = false);
    }
  }

  Widget _gradesSection(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<LessonGradesSummary>(
      future: _grades,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Text('Не удалось загрузить сохранённые оценки БАРС');
        }
        final info = snapshot.data!;
        final average = info.average;
        final noGrades = average == null &&
            info.currentScore == null &&
            info.finalGrade == null &&
            info.gradeLabels.isEmpty;
        if (noGrades) {
          return Text(
            'Нет сохранённых оценок по этому предмету в профиле. '
            'Открой профиль и обнови данные БАРС.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(context, 'Средний балл', average == null
                    ? '—' : average.toStringAsFixed(2)),
                _stat(context, 'Оценок (2–5)', '${info.gradeCount}'),
                if (info.currentScore != null)
                  _stat(context, 'Текущие баллы БАРС', info.currentScore!),
                if (info.finalGrade != null)
                  _stat(context, 'Итоговая оценка', info.finalGrade!),
              ],
            ),
            if (info.semester != null || info.attestation != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (info.semester != null) 'Семестр: ${info.semester}',
                  if (info.attestation != null)
                    'Аттестация: ${info.attestation}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (info.gradeLabels.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final label in info.gradeLabels.take(15))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $label', style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = lessonKind(
      widget.lesson.type,
      subject: widget.lesson.subject,
    );
    final color = lessonKindColor(kind);
    final date = widget.lesson.parsedDate;
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        20, 5, 20, MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.lesson.subject,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: color, size: 11),
              const SizedBox(width: 5),
              Text(lessonKindLabel(widget.lesson.type,
                  subject: widget.lesson.subject)),
            ]),
            Text(widget.lesson.time),
            if (date != null)
              Text('${date.day.toString().padLeft(2, '0')}.'
                  '${date.month.toString().padLeft(2, '0')}.${date.year}'),
          ],
        ),
        const SizedBox(height: 8),
        Text('Группа: ${widget.group}'),
        if (widget.lesson.room.trim().isNotEmpty)
          Text('Аудитория: ${widget.lesson.room}'),
        if (widget.lesson.teacher.trim().isNotEmpty)
          Text('Преподаватель: ${widget.lesson.teacher}'),
        const SizedBox(height: 22),
        Text('Мои оценки по предмету',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 6),
        Text('Данные из сохранённого профиля БАРС, не средний балл группы.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        _gradesSection(context),
        const SizedBox(height: 24),
        Text('Личная заметка',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 5),
        Text('Видна только на этом устройстве.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('personal-lesson-note'),
          controller: _personalController,
          enabled: !_personalLoading,
          minLines: 3,
          maxLines: 6,
          maxLength: 10000,
          decoration: const InputDecoration(
            hintText: 'Домашнее задание, тема, что повторить…',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: (_personalLoading || _personalSaving)
                ? null : _savePersonal,
            icon: const Icon(Icons.save_outlined),
            label: Text(_personalSaving ? 'Сохранение…' : 'Сохранить'),
          ),
        ),
        const SizedBox(height: 26),
        Text('Заметки для группы',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 6),
        Text(
          'Их видит любой, кто открывает расписание группы '
          '«${widget.group}». Не публикуй личные данные.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<GroupLessonNote>>(
          future: _shared,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text('Не удалось загрузить общие заметки: ${snapshot.error}'),
                  TextButton(
                    onPressed: () => setState(
                      () => _shared = _notesApi.list(widget.group, widget.lesson),
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              );
            }
            final notes = snapshot.data ?? [];
            if (notes.isEmpty) {
              return Text('Пока нет общих заметок.',
                  style: theme.textTheme.bodyMedium);
            }
            return Column(
              children: [
                for (final note in notes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.isMine ? 'Моя запись' : note.author,
                                    style: theme.textTheme.labelMedium),
                                const SizedBox(height: 6),
                                Text(note.content),
                              ],
                            ),
                          ),
                          if (note.isMine)
                            IconButton(
                              tooltip: 'Удалить свою заметку',
                              onPressed: _deleted ? null :
                                  () => _deleteNote(note.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('group-lesson-note'),
          controller: _sharedController,
          maxLength: 1500,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Написать для группы…',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _sharedSaving ? null : _publish,
            icon: const Icon(Icons.send_outlined),
            label: Text(_sharedSaving ? 'Публикация…' : 'Опубликовать'),
          ),
        ),
      ],
    );
  }
}
