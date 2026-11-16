import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '/features/schedule/data/attendance_api.dart';
import '../data/starosta_report_csv.dart';

/// Server-authorized headman's office. Peer data is never cached locally.
/// Reports are read on demand, and filters apply to the downloaded snapshot.
class StarostaCabinetScreen extends StatefulWidget {
  const StarostaCabinetScreen({super.key, this.api});
  final AttendanceApi? api;

  @override
  State<StarostaCabinetScreen> createState() => _StarostaCabinetScreenState();
}

class _StarostaCabinetScreenState extends State<StarostaCabinetScreen> {
  late final AttendanceApi _api = widget.api ?? AttendanceApi();
  final _student = TextEditingController();
  final _subject = TextEditingController();
  List<String> _groups = [];
  String? _selected;
  AttendanceRoster? _roster;
  List<AttendanceReportRow>? _report;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshAccess();
  }

  @override
  void dispose() {
    _student.dispose();
    _subject.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  String _short(Object error) => error.toString()
      .replaceFirst('Exception: ', '');

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _refreshAccess() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
      _roster = null;
    });
    try {
      final account = await _api.session();
      if (!account.authenticated) {
        throw Exception('Авторизуйся через БАРС в CampusApp');
      }
      final groups = await _api.managedGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selected = groups.contains(_selected)
            ? _selected : (groups.isEmpty ? null : groups.first);
      });
    } catch (error) {
      if (mounted) setState(() {
        _groups = [];
        _selected = null;
        _error = _short(error);
      });
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _loaded = true;
      });
    }
    if (mounted && _selected != null) await _loadRoster();
  }

  Future<void> _loadRoster() async {
    final group = _selected;
    if (group == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roster = await _api.roster(group: group);
      if (mounted && group == _selected) {
        setState(() => _roster = roster);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _short(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discover() async {
    if (_busy) return;
    setState(() => _busy = true);
    List<String> candidates;
    try {
      candidates = await _api.discoverGroups();
    } catch (error) {
      _notice('Не удалось получить группы БАРС: ' + _short(error));
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    if (candidates.isEmpty) {
      _notice('Меню БАРС не содержит доступных учебных групп');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Подтвердить учебную группу'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('Группы найдены в БАРС. Для каждой '
                'сервер отдельно проверяет статус старосты.'),
          ),
          for (final group in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, group),
              child: Text(group),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final groups = await _api.verifyManagedGroup(selected);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selected = selected;
        _report = null;
        _roster = null;
      });
      _notice('Права на группу ' + selected + ' подтверждены');
    } catch (error) {
      _notice('БАРС не подтвердил права: ' + _short(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _selected == selected) await _loadRoster();
  }

  Future<void> _syncRoster() async {
    final group = _selected;
    if (_busy || group == null) return;
    setState(() => _busy = true);
    try {
      final count = await _api.syncRoster(group: group);
      if (mounted) _notice('Обновлено студентов: $count');
    } catch (error) {
      _notice('Ошибка загрузки списка БАРС: ' + _short(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _loadRoster();
  }

  String _date(DateTime date) => date.day.toString().padLeft(2, '0') +
      '.' + date.month.toString().padLeft(2, '0') +
      '.' + date.year.toString();

  Future<void> _selectPeriod() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Отчёт за период (до 93 дней)',
    );
    if (dates == null || !mounted) return;
    if (dates.duration.inDays > 92) {
      _notice('Выбери период до 93 дней');
      return;
    }
    setState(() {
      _from = dates.start;
      _to = dates.end;
      _report = null;
    });
  }

  Future<void> _fetchReport() async {
    final group = _selected;
    if (group == null || _busy) return;
    setState(() => _busy = true);
    try {
      final rows = await _api.report(group, _from, _to);
      if (mounted && _selected == group) {
        setState(() => _report = rows);
      }
    } catch (error) {
      _notice('Не удалось получить отчёт: ' + _short(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<AttendanceReportRow> get _filteredReport {
    final student = _student.text.trim().toLowerCase();
    final subject = _subject.text.trim().toLowerCase();
    return [
      for (final row in _report ?? const <AttendanceReportRow>[])
        if (row.displayName.toLowerCase().contains(student) &&
            row.subject.toLowerCase().contains(subject)) row,
    ];
  }

  Future<void> _export() async {
    final group = _selected;
    if (group == null || _report == null || _busy) return;
    try {
      final documentDir = await getApplicationDocumentsDirectory();
      final safeGroup = group.replaceAll(RegExp(r'[^A-ZА-ЯЁ0-9-]'), '_');
      final fileName = 'campus_attendance_' + safeGroup + '_' +
          _date(_from).replaceAll('.', '') + '_' +
          _date(_to).replaceAll('.', '') + '.csv';
      final file = File(documentDir.path + '/' + fileName);
      await file.writeAsString(
        starostaReportCsv(group, _filteredReport),
        flush: true,
      );
      if (!mounted) return;
      _notice('Отчёт сохранён на устройстве');
      await OpenFilex.open(file.path);
    } catch (error) {
      _notice('Не удалось сохранить CSV: ' + _short(error));
    }
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _filteredReport;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кабинет старосты'),
        actions: [
          IconButton(
            key: const ValueKey('starosta-discover'),
            tooltip: 'Найти учебные группы БАРС',
            onPressed: _busy ? null : _discover,
            icon: const Icon(Icons.manage_search_outlined),
          ),
          IconButton(
            tooltip: 'Обновить права',
            onPressed: _busy ? null : _refreshAccess,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_loaded ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: TextStyle(
                color: theme.colorScheme.error)),
            ),
          if (_groups.isEmpty) ...[
            const ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Группы старосты не подтверждены'),
              subtitle: Text('Войди в БАРС и проверь доступ '
                'к своим учебным группам.'),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _discover,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Найти учебные группы'),
            ),
          ] else ...[
            _heading('Учебные группы'),
            DropdownButtonFormField<String>(
              key: const ValueKey('starosta-group'),
              value: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Выбери группу',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final group in _groups)
                  DropdownMenuItem(value: group, child: Text(group)),
              ],
              onChanged: _busy ? null : (group) {
                if (group == null || group == _selected) return;
                setState(() {
                  _selected = group;
                  _roster = null;
                  _report = null;
                  _student.clear();
                  _subject.clear();
                });
                _loadRoster();
              },
            ),
            _heading('Студенты'),
            Text(_roster == null ? 'Получение списка…'
                : _roster!.imported
                  ? 'Всего студентов: ' + _roster!.students.length.toString()
                  : 'Список ещё не загружен из БАРС.',
              style: theme.textTheme.bodyMedium),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              key: const ValueKey('starosta-roster-sync'),
              onPressed: _busy ? null : _syncRoster,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Обновить полный список БАРС'),
            ),
            if (_roster != null && _roster!.students.isNotEmpty)
              for (final student in _roster!.students)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(student.displayName),
                ),
            _heading('Отчёт о посещаемости'),
            Text('По закрытым журналам CampusApp. '
                'Это не официальный отчёт БАРС.',
              style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _selectPeriod,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(_date(_from) + ' — ' + _date(_to)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('starosta-report-load'),
              onPressed: _busy ? null : _fetchReport,
              icon: const Icon(Icons.assessment_outlined),
              label: const Text('Сформировать отчёт'),
            ),
            if (_report != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _student,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Фильтр по студенту',
                  prefixIcon: Icon(Icons.person_search_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subject,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Фильтр по предмету',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text('Отметок: ' + rows.length.toString()),
              OutlinedButton.icon(
                key: const ValueKey('starosta-report-export'),
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Экспорт CSV для Excel'),
              ),
              for (final row in rows.take(60))
                ListTile(
                  dense: true,
                  title: Text(row.displayName),
                  subtitle: Text(row.date + ' · ' + row.subject,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(switch (row.status) {
                    'absent' => 'Н',
                    'present' => '✓',
                    'excused' => 'У',
                    _ => '—',
                  }),
                ),
              if (rows.length > 60)
                Text('Показано 60 из ' + rows.length.toString() +
                    '. Экспорт содержит все строки с учётом фильтров.'),
            ],
          ],
        ],
      ),
    );
  }
}
