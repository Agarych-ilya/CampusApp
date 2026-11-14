import 'package:flutter/material.dart';

import '../data/attendance_api.dart';
import '../data/schedule_lesson.dart';

/// Student check-in and starosta review for ONE lesson from the real timetable.
class AttendanceLessonScreen extends StatefulWidget {
  const AttendanceLessonScreen({
    super.key,
    required this.group,
    required this.lesson,
    this.api,
  });

  final String group;
  final ScheduleLesson lesson;
  final AttendanceApi? api;

  @override
  State<AttendanceLessonScreen> createState() => _AttendanceLessonScreenState();
}

class _AttendanceLessonScreenState extends State<AttendanceLessonScreen> {
  late final AttendanceApi _api;
  AttendanceIdentity? _identity;
  AttendanceDetail? _detail;
  int? _lessonId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AttendanceApi();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  String _norm(String value) => value
      .trim().toUpperCase()
      .replaceAll('A', 'А')
      .replaceAll(RegExp(r'\s+'), '');

  String _label(String status) => switch (status) {
    'pending' => 'Ожидает проверки',
    'present' => 'Присутствует',
    'absent' => 'Пропуск',
    'excused' => 'Уважительная причина',
    'rejected' => 'Заявка отклонена',
    _ => 'Не отмечен',
  };

  Color _color(BuildContext context, String status) => switch (status) {
    'present' => Colors.green.shade400,
    'absent' => Colors.redAccent,
    'excused' => Colors.amber.shade400,
    'pending' => Theme.of(context).colorScheme.primary,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _api.session();
      if (!account.authenticated ||
          _norm(account.group ?? '') != _norm(widget.group)) {
        throw Exception(
          'Учебный журнал доступен только студентам этой группы, '
          'подтверждённым через БАРС',
        );
      }
      final date = widget.lesson.parsedDate;
      if (date == null) throw Exception('Дата пары не определена');
      final lessons = await _api.lessons(date);
      final existing = lessons.where((item) =>
          item.subject == widget.lesson.subject &&
          item.time == widget.lesson.time).toList();
      if (!mounted) return;
      if (existing.length > 1) {
        throw Exception('Найдено несколько журналов к одной паре');
      }
      final id = existing.isEmpty ? null : existing.single.id;
      final detail = id == null ? null : await _api.detail(id);
      if (!mounted) return;
      setState(() {
        _identity = account;
        _lessonId = id;
        _detail = detail;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) _message(success);
      await _load();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _register() async {
    final controller = TextEditingController(
      text: _identity?.displayName ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить себя в группу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Имя будет видно старосте для сверки списка. '
                'Учебная группа проверяется через БАРС.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 100,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Фамилия и имя',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    await _run(
      () => _api.register(name),
      'Ты добавлен в список своей группы',
    );
  }

  Future<void> _open() async {
    await _run(() async {
      _lessonId = await _api.open(widget.lesson);
    }, 'Журнал открыт для отметок');
  }

  Future<void> _checkIn() async {
    final id = _lessonId;
    if (id == null) return;
    await _run(
      () => _api.checkIn(id),
      'Заявка отправлена старосте для проверки',
    );
  }

  Future<void> _decide(AttendanceStudent student, String status) async {
    final id = _lessonId;
    if (id == null) return;
    await _run(
      () => _api.decide(id, student, status),
      'Отметка обновлена',
    );
  }

  Future<void> _confirmPending() async {
    final id = _lessonId;
    final pending = _detail?.students.where((student) =>
        student.status == 'pending').toList() ?? [];
    if (id == null || pending.isEmpty) return;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердить заявки?'),
        content: Text(
          'Подтвердить присутствие ${pending.length} студентов? '
          'Проверь, что они действительно были на паре.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (!mounted || allowed != true) return;
    await _run(() async {
      for (final student in pending) {
        await _api.decide(id, student, 'present');
      }
    }, 'Заявки подтверждены');
  }

  Future<void> _close() async {
    final detail = _detail;
    if (detail == null || !detail.readyToClose) {
      _message('Сначала проверь всех студентов группы', error: true);
      return;
    }
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть журнал?'),
        content: Text(
          'Проверь все отметки. Присутствовало: '
          '${detail.count('present')}, пропусков: '
          '${detail.count('absent')}, уважительных: '
          '${detail.count('excused')}. '
          'Запись в официальный БАРС пока не выполняется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (!mounted || allowed != true) return;
    await _run(
      () => _api.close(detail.lesson.id, detail.students),
      'Журнал закрыт. Доступен список для сверки с БАРС.',
    );
  }

  Future<void> _preview() async {
    if (_lessonId == null) return;
    try {
      final result = await _api.barsPreview(_lessonId!);
      if (!mounted) return;
      final absences = (result['absences'] as List? ?? []).whereType<Map>()
          .map((item) => item['displayName']?.toString() ?? 'Студент')
          .toList();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Список для БАРС'),
          content: SingleChildScrollView(
            child: Text(
              'Это предпросмотр — официальный БАРС не изменён.\n\n'
              'Пропуски:\n'
              '${absences.isEmpty ? 'Нет' : absences.join('\n')}',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Widget _studentTile(AttendanceStudent student) {
    final theme = Theme.of(context);
    final open = _detail?.lesson.state == 'open';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 5),
            Text(_label(student.status),
                style: TextStyle(color: _color(context, student.status))),
            if (open) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : () => _decide(student, 'present'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Был'),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : () => _decide(student, 'absent'),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Пропуск'),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : () => _decide(student, 'excused'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Уваж.'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = _identity;
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Учебный журнал'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.lesson.subject,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${widget.group} · ${widget.lesson.date} · '
                      '${widget.lesson.time}'),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(_error!, style: TextStyle(
                          color: theme.colorScheme.error,
                        )),
                      ),
                    ),
                  if (account != null && account.authenticated) ...[
                    if (account.isStarosta)
                      const Text('Режим старосты',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    if (!account.registered) ...[
                      const SizedBox(height: 12),
                      const Text('Добавь себя в список группы, чтобы '
                          'отмечаться на занятиях.'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _register,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Добавить себя'),
                      ),
                    ] else ...[
                      Text('Ты в списке: ${account.displayName ?? ''}'),
                      const SizedBox(height: 10),
                    ],
                    if (detail == null) ...[
                      const SizedBox(height: 14),
                      const Text('Староста ещё не открыл журнал этой пары.'),
                      if (account.isStarosta) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _open,
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text('Открыть журнал пары'),
                        ),
                      ],
                    ] else ...[
                      Text(
                        detail.lesson.state == 'closed'
                            ? 'Журнал закрыт'
                            : 'Приём отметок открыт',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (!account.isStarosta) ...[
                        const SizedBox(height: 12),
                        Text('Моя отметка: ${_label(detail.myStatus ?? 'unmarked')}'),
                        const SizedBox(height: 10),
                        if (detail.lesson.state == 'open' &&
                            account.registered &&
                            ['unmarked', 'pending']
                              .contains(detail.myStatus ?? 'unmarked'))
                          FilledButton.icon(
                            onPressed: _saving ? null : _checkIn,
                            icon: const Icon(Icons.how_to_reg),
                            label: Text(detail.myStatus == 'pending'
                                ? 'Отправить повторно'
                                : 'Я присутствую'),
                          ),
                        const SizedBox(height: 10),
                        const Text('Отметка ожидает подтверждения старосты. '
                            'Если ты не нажал кнопку, это не означает '
                            'автоматический пропуск.'),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Заявок: ${detail.count('pending')} · '
                          'Присутствует: ${detail.count('present')} · '
                          'Без отметки: ${detail.count('unmarked')}',
                        ),
                        const SizedBox(height: 12),
                        if (detail.lesson.state == 'open' &&
                            detail.count('pending') > 0)
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _confirmPending,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Подтвердить заявки'),
                          ),
                        const SizedBox(height: 12),
                        for (final student in detail.students)
                          _studentTile(student),
                        if (detail.lesson.state == 'open') ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving || !detail.readyToClose
                                ? null : _close,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Закрыть проверенный журнал'),
                          ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: _preview,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Список для БАРС'),
                          ),
                        ],
                      ],
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
