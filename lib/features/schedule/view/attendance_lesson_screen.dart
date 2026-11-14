import 'package:flutter/material.dart';

import '/features/auth/view/login_screen.dart';
import '/features/services/listings/data/listings_api.dart';
import '../data/attendance_api.dart';
import 'bars_roster_import_screen.dart';
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
  AttendanceRoster? _roster;
  Set<String> _absentKeys = {};
  final TextEditingController _search = TextEditingController();
  bool _showAbsentOnly = false;
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
    _search.dispose();
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

  bool _requiresBarsReconnect(String error) =>
      error.contains('БАРС отклонил сессию') ||
      error.contains('перенаправил на вход') ||
      error.contains('Нет подтверждённой сессии БАРС') ||
      error.contains('Сессия БАРС не найдена') ||
      error.contains('БАРС не подтвердил сессию');

  Future<void> _reconnectBars() async {
    // The profile cached at app startup is not itself a live BARS session.
    // Reuse the existing BARS WebView login without logging out of CampusApp.
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnToPreviousScreen: true),
      ),
    );
    if (!mounted) return;
    if (authenticated == true) await _load();
  }

  Future<void> _refreshStarostaRole() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      await ListingsApi.instance.refreshBarsRole();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      if (_identity?.isStarosta != true) {
        _message(
          'БАРС не подтвердил права старосты. Проверь, доступна ли '
          'страница своей учебной группы в БАРС.',
          error: true,
        );
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
      final roster = account.isStarosta ? await _api.roster() : null;
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
        _roster = roster;
        _lessonId = id;
        _detail = detail;
        _absentKeys = {
          if (detail != null)
            for (final student in detail.students)
              if (student.status == 'absent') student.ownerKey,
        };
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

  Future<void> _importFromBars() async {
    if (_identity?.isStarosta != true || _saving) return;
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BarsRosterImportScreen(
        group: widget.group, api: _api,
      )),
    );
    if (mounted && imported == true) await _load();
  }

  Future<void> _saveReviewedAbsences() async {
    final detail = _detail;
    if (_identity?.isStarosta != true || detail == null || _saving ||
        detail.lesson.state != 'open') return;
    final roster = detail.students;
    if (roster.isEmpty || _roster?.imported != true) {
      _message('Сначала загрузи полный список группы из БАРС', error: true);
      return;
    }
    final absent = roster.where((student) =>
        _absentKeys.contains(student.ownerKey)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердить посещаемость?'),
        content: SingleChildScrollView(child: Text(
          'Всего студентов: ${roster.length}\n'
          'Отсутствовали: ${absent.length}\n'
          'Присутствовали: ${roster.length - absent.length}\n\n'
          '${absent.isEmpty ? 'Отсутствующих нет' :
            absent.map((student) => student.displayName).join('\n')}\n\n'
          'Проверь, что список группы полный. Это сохранит отметки '
          'в CampusApp и закроет журнал. Официальный БАРС не изменяется.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(
      () => _api.saveAbsences(
        detail.lesson.id,
        roster.map((student) => student.ownerKey).toList(),
        Set.of(_absentKeys),
      ),
      'Посещаемость сохранена в CampusApp',
    );
  }

  String _initials(String name) {
    final pieces = name.trim().split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty).toList();
    if (pieces.isEmpty) return '?';
    if (pieces.length == 1) return pieces.first.substring(0, 1).toUpperCase();
    return (pieces.first.substring(0, 1) +
        pieces[1].substring(0, 1)).toUpperCase();
  }

  Widget _summaryItem(
    String title, int count, Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text('$count',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _absenceTile(AttendanceStudent student, {required bool closed}) {
    final theme = Theme.of(context);
    final absent = closed ? student.status == 'absent'
        : _absentKeys.contains(student.ownerKey);
    final red = const Color(0xFFEF566E);
    final color = absent ? red : theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: absent ? red.withOpacity(0.09) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: absent ? red.withOpacity(0.55) :
              theme.colorScheme.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: InkWell(
        key: ValueKey('attendance-absent-${student.ownerKey}'),
        borderRadius: BorderRadius.circular(15),
        onTap: _saving || closed ? null : () => setState(() {
          if (absent) {
            _absentKeys.remove(student.ownerKey);
          } else {
            _absentKeys.add(student.ownerKey);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: absent
                    ? red.withOpacity(0.15)
                    : theme.colorScheme.primary.withOpacity(0.1),
                child: Text(_initials(student.displayName),
                  style: TextStyle(
                    color: absent ? red : theme.colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  )),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.displayName,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                    const SizedBox(height: 3),
                    Text(absent ? 'Отсутствует' : 'Присутствует',
                      style: theme.textTheme.bodySmall?.copyWith(color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (absent)
                Container(
                  key: const ValueKey('attendance-student-absence'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: red,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text('Н',
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 15)),
                )
              else
                Icon(Icons.circle_outlined, size: 24,
                  color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = _identity;
    final detail = _detail;
    final reviewed = account?.isStarosta == true &&
        detail != null && detail.students.isNotEmpty;
    final isClosed = detail?.lesson.state == 'closed';
    final filter = _search.text.trim().toLowerCase();
    final shown = reviewed
        ? detail.students.where((student) {
            if (_showAbsentOnly) {
              final absent = isClosed
                  ? student.status == 'absent'
                  : _absentKeys.contains(student.ownerKey);
              if (!absent) return false;
            }
            return student.displayName.toLowerCase().contains(filter);
          }).toList()
        : <AttendanceStudent>[];
    final total = reviewed ? detail.students.length : 0;
    final missing = reviewed
        ? (isClosed
            ? detail.students.where((s) => s.status == 'absent').length
            : _absentKeys.length)
        : 0;
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!, style: TextStyle(
                              color: theme.colorScheme.error,
                            )),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const ValueKey('attendance-retry-session'),
                              onPressed: _saving || _loading ? null : _load,
                              icon: const Icon(Icons.refresh_outlined),
                              label: const Text('Повторить проверку'),
                            ),
                            if (_requiresBarsReconnect(_error!)) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                key: const ValueKey('attendance-reconnect-bars'),
                                onPressed: _saving || _loading
                                    ? null : _reconnectBars,
                                icon: const Icon(Icons.login),
                                label: const Text('Обновить вход в БАРС'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (account != null && account.authenticated) ...[
                    if (account.isStarosta) ...[
                      const Text('Режим старосты',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(_roster?.imported == true
                          ? 'Загружено студентов: ${_roster!.students.length}'
                          : 'Список группы ещё не загружен из БАРС'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('bars-import-roster-entry'),
                        onPressed: _saving ? null : _importFromBars,
                        icon: const Icon(Icons.group_add_outlined),
                        label: Text(_roster?.imported == true
                            ? 'Обновить список группы'
                            : 'Загрузить группу из БАРС'),
                      ),
                    ] else ...[
                      const Text('Учебный журнал ведёт староста группы. '
                          'ФИО студентов загружаются из БАРС, '
                          'вводить их вручную не требуется.'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('attendance-check-starosta-role'),
                        onPressed: _saving || _loading
                            ? null : _refreshStarostaRole,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Проверить права старосты'),
                      ),
                    ],
                    if (detail == null) ...[
                      const SizedBox(height: 14),
                      const Text('Староста ещё не открыл журнал этой пары.'),
                      if (account.isStarosta) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving || _roster?.imported != true
                              ? null : _open,
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
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isClosed ? 'Итоговые отметки'
                                : 'Посещаемость группы',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              )),
                            if (!isClosed)
                              Text('Выбери отсутствующих',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryItem('Всего', total,
                                theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            _summaryItem('Присутствуют', total - missing,
                                const Color(0xFF4BBE91)),
                            const SizedBox(width: 8),
                            _summaryItem('Отсутствуют', missing,
                                const Color(0xFFEF566E)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (detail.students.isEmpty)
                          const Text('Сначала загрузи полный список '
                              'студентов из БАРС.')
                        else ...[
                          TextField(
                            key: const ValueKey('attendance-search'),
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Найти студента по ФИО',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _search.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 19),
                                      onPressed: () => setState(_search.clear),
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ChoiceChip(
                                key: const ValueKey('attendance-filter-all'),
                                label: const Text('Все'),
                                selected: !_showAbsentOnly,
                                onSelected: (_) => setState(
                                  () => _showAbsentOnly = false),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                key: const ValueKey('attendance-filter-absent'),
                                label: Text('Отсутствуют ($missing)'),
                                selected: _showAbsentOnly,
                                onSelected: (_) => setState(
                                  () => _showAbsentOnly = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final student in shown)
                            _absenceTile(student, closed: isClosed),
                          if (shown.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Center(child: Text(
                                'По этому запросу студентов нет',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                              )),
                            ),
                        ],
                        if (isClosed) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _preview,
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Список для БАРС'),
                          ),
                        ],

                      ],
                    ],
                  ],
                ],
              ),
            ),
      bottomNavigationBar: reviewed && !isClosed
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  )),
                ),
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    key: const ValueKey('save-reviewed-absences'),
                    onPressed: _saving ? null : _saveReviewedAbsences,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('Сохранить · отсутствуют $missing'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
