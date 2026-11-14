import 'package:flutter/material.dart';

import '/features/auth/view/login_screen.dart';
import '/features/services/listings/data/listings_api.dart';
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
  AttendanceRoster? _roster;
  Set<String> _absentKeys = {};
  final TextEditingController _search = TextEditingController();
  bool _showAbsentOnly = false;
  bool _attemptedAutoImport = false;
  String? _rosterError;
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

  Future<void> _retryRoster() async {
    if (_loading || _saving) return;
    _attemptedAutoImport = false;
    await _load();
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
      var roster = account.isStarosta ? await _api.roster() : null;
      if (account.isStarosta && roster?.imported != true &&
          widget.api == null && !_attemptedAutoImport) {
        _attemptedAutoImport = true;
        try {
          await _api.syncRoster();
          roster = await _api.roster();
          _rosterError = null;
        } catch (error) {
          _rosterError = error.toString().replaceFirst('Exception: ', '');
        }
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

  /// A plain attendance row: a name and one status control, no avatars,
  /// decorative statistic cards or colour-coded labels for every student.
  Widget _absenceTile(AttendanceStudent student, {required bool closed}) {
    final theme = Theme.of(context);
    final absent = closed
        ? student.status == 'absent'
        : _absentKeys.contains(student.ownerKey);
    final muted = theme.colorScheme.onSurfaceVariant;
    const absenceColor = Color(0xFFEF566E);

    return InkWell(
      key: ValueKey('attendance-absent-${student.ownerKey}'),
      onTap: _saving || closed ? null : () => setState(() {
        if (absent) {
          _absentKeys.remove(student.ownerKey);
        } else {
          _absentKeys.add(student.ownerKey);
        }
      }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.45),
          )),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                student.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (absent)
              Container(
                key: const ValueKey('attendance-student-absence'),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: const Text('Н', style: TextStyle(
                  color: absenceColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
              )
            else if (!closed)
              Icon(Icons.radio_button_unchecked, size: 23, color: muted)
            else if (student.status == 'present')
              Icon(Icons.check, size: 20, color: muted)
            else
              Text(_label(student.status),
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
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
        ? detail!.students.where((student) {
            if (_showAbsentOnly) {
              final absent = isClosed
                  ? student.status == 'absent'
                  : _absentKeys.contains(student.ownerKey);
              if (!absent) return false;
            }
            return student.displayName.toLowerCase().contains(filter);
          }).toList()
        : <AttendanceStudent>[];
    final total = reviewed ? detail!.students.length : 0;
    final missing = reviewed
        ? (isClosed
            ? detail!.students.where((s) => s.status == 'absent').length
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
                        fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${widget.group} · ${widget.lesson.date} · '
                      '${widget.lesson.time}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
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
                      if (_roster?.imported != true) ...[
                        Text(_rosterError ??
                            'Не удалось получить список группы с сервера БАРС.'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('attendance-retry-roster'),
                          onPressed: _retryRoster,
                          icon: const Icon(Icons.sync),
                          label: const Text('Повторить загрузку'),
                        ),
                      ],
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
                      if (!account.isStarosta)
                        Text(
                          detail.lesson.state == 'closed'
                              ? 'Журнал закрыт'
                              : 'Приём отметок открыт',
                          style: theme.textTheme.bodyMedium,
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
                        const SizedBox(height: 14),
                        Text(
                          'Студентов: $total · Отсутствуют: $missing'
                          '${isClosed ? ' · Журнал закрыт' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!isClosed) ...[
                          const SizedBox(height: 5),
                          Text('Нажми на студента, чтобы отметить пропуск',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        ],
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
                              TextButton(
                                key: const ValueKey('attendance-filter-all'),
                                onPressed: () => setState(
                                  () => _showAbsentOnly = false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                ),
                                child: Text('Все', style: TextStyle(
                                  fontWeight: !_showAbsentOnly
                                      ? FontWeight.w700 : FontWeight.w400,
                                  color: !_showAbsentOnly
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                )),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                key: const ValueKey('attendance-filter-absent'),
                                onPressed: () => setState(
                                  () => _showAbsentOnly = true),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                ),
                                child: Text('Отсутствуют ($missing)',
                                  style: TextStyle(
                                    fontWeight: _showAbsentOnly
                                        ? FontWeight.w700 : FontWeight.w400,
                                    color: _showAbsentOnly
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                  )),
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
                  child: FilledButton(
                    key: const ValueKey('save-reviewed-absences'),
                    onPressed: _saving ? null : _saveReviewedAbsences,
                    child: const Text('Сохранить посещаемость'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
