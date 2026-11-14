import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/attendance_api.dart';

/// The user navigates to BARS → Учебные группы → their group → Студенты.
/// We read ONLY the visible table from the official HTTPS BARS origin.
/// Import is a previewable CampusApp copy, never an official BARS edit.
class BarsRosterImportScreen extends StatefulWidget {
  const BarsRosterImportScreen({
    super.key, required this.group, required this.api,
  });

  final String group;
  final AttendanceApi api;

  @override
  State<BarsRosterImportScreen> createState() =>
      _BarsRosterImportScreenState();
}

class _BarsRosterImportScreenState extends State<BarsRosterImportScreen> {
  late final WebViewController _web;
  List<BarsRosterStudent>? _preview;
  String? _error;
  bool _busy = false;
  bool _loading = true;
  String _page = '';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          setState(() { _loading = true; _page = url; _error = null; });
        },
        onPageFinished: (url) {
          if (!mounted) return;
          setState(() { _loading = false; _page = url; });
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          setState(() => _error = 'Не удалось открыть страницу БАРС');
        },
      ))
      ..loadRequest(Uri.parse(
        'https://bars.mpei.ru/bars_web/SG/StudyGroup/ListStudyGroup',
      ));
  }

  /// Android often JSON-quotes JavaScript's JSON string a second time.
  static dynamic unpackJavascriptResult(Object raw) {
    dynamic value = raw;
    for (var i = 0; i < 3 && value is String; i++) {
      value = jsonDecode(value);
    }
    return value;
  }

  Future<void> _readVisibleRoster() async {
    if (_busy || _loading) return;
    final uri = Uri.tryParse(await _web.currentUrl() ?? '');
    if (uri == null || uri.scheme != 'https' ||
        uri.host != 'bars.mpei.ru' ||
        !uri.path.startsWith('/bars_web/')) {
      setState(() => _error =
          'Открой вкладку «Студенты» на официальном сайте БАРС');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final script = r'''
        (function () {
          const expected = __GROUP__;
          const clean = s => String(s || '').replace(/\u00a0/g, ' ')
            .replace(/\s+/g, ' ').trim();
          const text = clean(document.body.innerText);
          const groupKey = s => clean(s).toUpperCase()
            .replace(/A(?=-[0-9])/g, 'А').replace(/[–—−]/g, '-');
          if (!groupKey(text).includes(groupKey(expected))) {
            return JSON.stringify({error: 'На странице не найдена группа ' + expected});
          }
          const students = [];
          const seen = new Set();
          for (const table of document.querySelectorAll('table')) {
            // General group page also lists staff responsible for journals
            // with Фамилия / Имя columns. Never import that staff table.
            // Student rows must come from a VISIBLE student-specific grid.
            const marker = String(table.id || '') + ' ' +
              String(table.getAttribute('data-q-href') || '');
            if (!/student|studlist/i.test(marker) ||
                /responsib|journal|teacher/i.test(marker) ||
                table.getClientRects().length === 0) continue;
            const headerRows = Array.from(table.querySelectorAll('thead tr'));
            const header = headerRows.map(row =>
              Array.from(row.querySelectorAll('th')).map(th =>
                clean(th.innerText).toLowerCase())).find(cols =>
                cols.some(s => s.includes('фамилия')) &&
                cols.some(s => s === 'имя' || s.startsWith('имя ')) ||
                cols.some(s => s === 'фио' || s.includes('ф.и.о') ||
                  s.includes('фамилия имя отчество') || s === 'студент'));
            if (!header) continue;
            const family = header.findIndex(s => s.includes('фамилия'));
            const name = header.findIndex(s => s === 'имя' || s.startsWith('имя '));
            const father = header.findIndex(s => s.includes('отчество'));
            const fio = header.findIndex(s => s === 'фио' ||
              s.includes('ф.и.о') || s.includes('фамилия имя отчество') ||
              s === 'студент');
            for (const tr of table.querySelectorAll('tbody tr')) {
              const cells = Array.from(tr.querySelectorAll(':scope > td'));
              if (!cells.length) continue;
              const value = index => index >= 0 && index < cells.length
                ? clean(cells[index].innerText) : '';
              const fullName = fio >= 0 ? value(fio) :
                clean([value(family), value(name), value(father)].join(' '));
              if (!/^[\p{L} .'-]+$/u.test(fullName) ||
                  fullName.split(' ').filter(Boolean).length < 2 ||
                  fullName.length > 120) continue;
              const normalized = fullName.toLocaleLowerCase('ru-RU');
              if (seen.has(normalized)) {
                return JSON.stringify({error:
                  'Найдены одинаковые ФИО. Нужен уникальный ID каждого студента'});
              }
              seen.add(normalized);
              let id = null;
              const anchors = Array.from(tr.querySelectorAll('a[href]'));
              for (const a of anchors) {
                try {
                  const link = new URL(a.href, location.href);
                  if (link.host !== location.host) continue;
                  id = ['studentID','stID','studID','studentId'].map(key =>
                    link.searchParams.get(key)).find(Boolean) || null;
                  if (id) break;
                } catch (_) {}
              }
              students.push({
                fullName: fullName,
                ...(id && /^[a-zA-Z0-9_-]{1,120}$/.test(id)
                  ? {sourceId: id} : {}),
              });
            }
          }
          return JSON.stringify({
            group: expected, students: students,
            error: students.length ? null :
              'Не найдена таблица именно вкладки «Студенты». ' +
              'Открой её в своей группе и дождись полной загрузки. ' +
              'Таблица ответственных за журнал не подходит.',
          });
        })()
      '''.replaceFirst('__GROUP__', jsonEncode(widget.group));

      final raw = await _web.runJavaScriptReturningResult(script);
      final extracted = unpackJavascriptResult(raw);
      if (extracted is! Map) {
        throw const FormatException('Не удалось прочитать таблицу БАРС');
      }
      final error = extracted['error']?.toString();
      if (error != null && error.isNotEmpty && error != 'null') {
        throw FormatException(error);
      }
      final rawStudents = extracted['students'];
      if (rawStudents is! List || rawStudents.length < 3 ||
          rawStudents.length > 120) {
        throw const FormatException(
          'Проверь, что загружена вся группа: найдено меньше 3 или больше 120 строк',
        );
      }
      final students = <BarsRosterStudent>[];
      for (final row in rawStudents) {
        if (row is! Map || row['fullName'] is! String) {
          throw const FormatException('Неверный формат списка студентов');
        }
        students.add(BarsRosterStudent(
          fullName: (row['fullName'] as String).trim(),
          sourceId: row['sourceId']?.toString(),
        ));
      }
      if (mounted) setState(() => _preview = students);
    } catch (error) {
      if (mounted) setState(() => _error =
          error.toString().replaceFirst('FormatException: ', '')
              .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_preview == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.importRoster(widget.group, _preview!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error =
          error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Список группы из БАРС')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              const Text('Открой: Учебные группы → своя группа → Студенты. '
                  'Затем нажми «Считать список». ФИО вручную вводить не нужно.'),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                )),
              ],
            ],
          ),
        ),
        if (preview == null) ...[
          Expanded(child: WebViewWidget(controller: _web)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              key: const ValueKey('bars-read-roster'),
              onPressed: _busy || _loading ? null : _readVisibleRoster,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Считать список студентов'),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Найдено студентов: ${preview.length}. '
                'Проверь список перед импортом.'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: preview.length,
              itemBuilder: (_, i) => ListTile(
                dense: true, leading: Text('${i + 1}'),
                title: Text(preview[i].fullName),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _preview = null),
                child: const Text('Назад'),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                key: const ValueKey('bars-import-roster'),
                onPressed: _busy ? null : _import,
                child: Text(_busy ? 'Сохранение...' :
                    'Загрузить ${preview.length}'),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}
