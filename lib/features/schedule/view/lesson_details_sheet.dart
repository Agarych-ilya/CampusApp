import 'package:flutter/material.dart';

import '../data/group_lesson_notes_api.dart';
import '../data/lesson_grades_summary.dart';
import '../data/lesson_kind.dart';
import '../data/private_lesson_notes_storage.dart';
import '../data/own_lesson_note_preview_storage.dart';
import '../data/schedule_lesson.dart';
import 'attendance_lesson_screen.dart';

/// A bottom-sheet opened from a timetable lesson.
class LessonDetailsSheet extends StatefulWidget {
  const LessonDetailsSheet({
    super.key,
    required this.group,
    required this.lesson,
    required this.scrollController,
    this.notesApi,
    this.onNotesChanged,
  });

  final String group;
  final ScheduleLesson lesson;
  final ScrollController scrollController;
  final GroupLessonNotesApi? notesApi;
  final VoidCallback? onNotesChanged;

  @override
  State<LessonDetailsSheet> createState() => _LessonDetailsSheetState();
}

class _LessonDetailsSheetState extends State<LessonDetailsSheet> {
  final _noteController = TextEditingController();
  final _privateStore = PrivateLessonNotesStorage();
  final _previewStore = OwnLessonNotePreviewStorage();
  late final GroupLessonNotesApi _notesApi;
  late Future<LessonGradesSummary> _grades;
  Future<List<GroupLessonNote>>? _shared;
  bool _forGroup = false;
  bool _personalLoading = true;
  bool _saving = false;
  bool _deleting = false;
  String _privateDraft = '';
  String _sharedDraft = '';

  @override
  void initState() {
    super.initState();
    _notesApi = widget.notesApi ?? GroupLessonNotesApi();
    _grades = LessonGradesSummary.load(widget.lesson.subject);
    _loadPersonal();
  }

  @override
  void dispose() {
    _noteController.dispose();
    if (widget.notesApi == null) _notesApi.dispose();
    super.dispose();
  }

  /// Synchronize the local card preview after reading actual server notes.
  Future<List<GroupLessonNote>> _loadSharedNotes() async {
    final notes = await _notesApi.list(widget.group, widget.lesson);
    final own = notes.where((note) => note.isMine).toList();
    final last = own.isEmpty ? '' : own.first.content;
    await _previewStore.savePublished(
      group: widget.group,
      lesson: widget.lesson,
      content: last,
    );
    widget.onNotesChanged?.call();
    return notes;
  }

  Future<void> _loadPersonal() async {
    try {
      final text = await _privateStore.load(
        group: widget.group,
        lesson: widget.lesson,
      );
      if (!mounted) return;
      _privateDraft = text;
      if (!_forGroup) _noteController.text = text;
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

  void _switchRecipient(bool toGroup) {
    if (_saving || _forGroup == toGroup) return;
    if (_forGroup) {
      _sharedDraft = _noteController.text;
    } else {
      _privateDraft = _noteController.text;
    }
    setState(() {
      _forGroup = toGroup;
      _noteController.text = toGroup ? _sharedDraft : _privateDraft;
      if (toGroup) {
        _shared ??= _loadSharedNotes();
      }
    });
  }

  Future<void> _saveNote() async {
    if (_saving || (_personalLoading && !_forGroup)) return;
    final content = _noteController.text;
    if (_forGroup && content.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_forGroup) {
        await _notesApi.create(widget.group, widget.lesson, content.trim());
        // Server owns the note; the device keeps a quick own-note preview.
        await _previewStore.savePublished(
          group: widget.group,
          lesson: widget.lesson,
          content: content.trim(),
        );
        if (!mounted) return;
        widget.onNotesChanged?.call();
        _sharedDraft = '';
        _noteController.clear();
        setState(() {
          _shared = _loadSharedNotes();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заметка опубликована для группы')),
        );
      } else {
        await _privateStore.save(
          group: widget.group,
          lesson: widget.lesson,
          content: content,
        );
        if (!mounted) return;
        _privateDraft = content;
        widget.onNotesChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Личная заметка сохранена')),
        );
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNote(int id) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await _notesApi.delete(id);
      // Fetch the remaining own notes before updating the card's preview.
      final refreshed = await _loadSharedNotes();
      if (!mounted) return;
      setState(() {
        _shared = Future.value(refreshed);
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _sharedNotes(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<GroupLessonNote>>(
      future: _shared,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text(
                'Заметки группы доступны только студентам '
                'с подтверждённой группой БАРС.',
              ),
              TextButton(
                onPressed: () => setState(() =>
                    _shared = _loadSharedNotes()),
                child: const Text('Повторить'),
              ),
            ],
          );
        }
        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Text('Общих заметок пока нет.',
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
                          onPressed: _deleting
                              ? null : () => _deleteNote(note.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
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
        const SizedBox(height: 18),
        // Attendance belongs to the selected lesson, not the Services tab.
        OutlinedButton.icon(
          key: const ValueKey('open-attendance-journal'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AttendanceLessonScreen(
                group: widget.group,
                lesson: widget.lesson,
              ),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Учебный журнал · посещаемость'),
        ),
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
        Text('Заметка',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          key: const ValueKey('lesson-note-recipient'),
          segments: const [
            ButtonSegment<bool>(
              value: false,
              label: Text('Для себя'),
              icon: Icon(Icons.lock_outline),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('Для группы'),
              icon: Icon(Icons.groups_outlined),
            ),
          ],
          selected: {_forGroup},
          onSelectionChanged: (values) => _switchRecipient(values.first),
        ),
        const SizedBox(height: 10),
        Text(
          _forGroup
              ? 'Заметка будет доступна только студентам группы '
                '${widget.group}, подтверждённым через БАРС.'
              : 'Личная заметка видна только на этом устройстве.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('lesson-note-composer'),
          controller: _noteController,
          enabled: !_saving && (!_personalLoading || _forGroup),
          minLines: 3,
          maxLines: 6,
          maxLength: _forGroup ? 1500 : 10000,
          decoration: InputDecoration(
            hintText: _forGroup
                ? 'Написать сообщение для группы…'
                : 'Домашнее задание, тема, что повторить…',
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('lesson-note-save'),
            onPressed: _saving ? null : _saveNote,
            icon: Icon(_forGroup ? Icons.send_outlined : Icons.save_outlined),
            label: Text(_saving
                ? 'Сохранение…'
                : _forGroup ? 'Опубликовать' : 'Сохранить'),
          ),
        ),
        if (_forGroup) ...[
          const SizedBox(height: 24),
          Text('Заметки группы',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 12),
          _sharedNotes(context),
        ],
      ],
    );
  }
}
