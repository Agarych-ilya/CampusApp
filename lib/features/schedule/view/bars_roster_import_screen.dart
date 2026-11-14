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
  bool _manual = false;
  bool _autoRunning = false;
  String _progress = 'Открываем учебные группы БАРС...';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          setState(() { _loading = true; _error = null; });
        },
        onPageFinished: (url) {
          if (!mounted) return;
          setState(() { _loading = false; });
          if (!_manual && !_autoRunning && _preview == null) {
            _autoNavigate();
          }
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          setState(() {
            _error = 'Не удалось открыть страницу БАРС';
            _manual = true;
          });
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

  Future<Map<String, dynamic>> _runJson(String script) async {
    final raw = await _web.runJavaScriptReturningResult(script);
    final value = unpackJavascriptResult(raw);
    if (value is! Map) {
      throw const FormatException('БАРС вернул неожиданные данные');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<bool> _onBars() async {
    final uri = Uri.tryParse(await _web.currentUrl() ?? '');
    return uri != null && uri.scheme == 'https' &&
        uri.host == 'bars.mpei.ru' && uri.path.startsWith('/bars_web/');
  }

  String _nextPageScript() => r'''
    (function () {
      const expected = __GROUP__;
      const clean = s => String(s || '').replace(/\u00a0/g, ' ')
        .replace(/\s+/g, ' ').trim();
      const norm = s => clean(s).toUpperCase()
        .replace(/[AА](?=-\d)/g, 'А').replace(/[–—−]/g, '-');
      const safe = a => {
        try {
          const href = a.getAttribute('href');
          if (!href || /^javascript:/i.test(href)) return false;
          const url = new URL(href, location.href);
          return url.origin === 'https://bars.mpei.ru' &&
            url.pathname.startsWith('/bars_web/');
        } catch (_) { return false; }
      };
      if (/\/(Login|SignIn)\/?$/i.test(location.pathname)) {
        return JSON.stringify({action: 'login'});
      }
      const tables = Array.from(document.querySelectorAll('table'))
        .filter(t => t.getClientRects().length > 0 &&
          Array.from(t.querySelectorAll('th')).some(x =>
            clean(x.innerText).toLowerCase() === 'фио') &&
          Array.from(t.querySelectorAll('th')).some(x =>
            clean(x.innerText).toLowerCase().includes('статус обучения')));
      const pageText = norm(document.body?.innerText);
      if (tables.length === 1 && pageText.includes(norm(expected))) {
        return JSON.stringify({action: 'students'});
      }
      if (/\/StudyGroup\/ListStudyGroup\/?$/i.test(location.pathname)) {
        const links = Array.from(document.querySelectorAll('a[href]'))
          .filter(a => norm(a.innerText) === norm(expected) && safe(a) &&
            /\/SG\/StudyGroup\/EditStudyGroup\/?$/i.test(
              new URL(a.href, location.href).pathname));
        if (links.length === 1) {
          links[0].click();
          return JSON.stringify({action: 'group'});
        }
        if (links.length > 1) return JSON.stringify({action: 'ambiguous'});
        return JSON.stringify({action: 'wait'});
      }
      if (/\/StudyGroup\/EditStudyGroup\/?$/i.test(location.pathname) &&
          pageText.includes(norm(expected))) {
        const links = Array.from(document.querySelectorAll('a[href]'))
          .filter(a => clean(a.innerText).toLowerCase() === 'студенты' &&
            safe(a));
        if (links.length === 1) {
          links[0].click();
          return JSON.stringify({action: 'tab'});
        }
        const tabs = Array.from(document.querySelectorAll(
          'nav a, aside a, .list-group a, .sidebar a, [role="tab"]'))
          .filter(a => clean(a.innerText).toLowerCase() === 'студенты');
        if (tabs.length === 1) {
          tabs[0].click();
          return JSON.stringify({action: 'tab'});
        }
      }
      return JSON.stringify({action: 'wait'});
    })()
  '''.replaceFirst('__GROUP__', jsonEncode(widget.group));

  Future<void> _autoNavigate() async {
    if (!mounted || _manual || _autoRunning || _preview != null) return;
    setState(() { _autoRunning = true; _error = null; });
    try {
      // AJAX tabs may not trigger onPageFinished; poll with a strict limit.
      for (var attempt = 0; attempt < 55; attempt++) {
        if (!mounted || _manual || _preview != null) return;
        if (_loading || !await _onBars()) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        try {
          final response = await _runJson(_nextPageScript());
          final action = response['action'];
          if (!mounted || _manual) return;
          if (action == 'students') {
            setState(() => _progress = 'Считываем студентов...');
            if (await _extractRoster()) return;
          } else if (action == 'group') {
            setState(() => _progress = 'Открываем группу...');
          } else if (action == 'tab') {
            setState(() => _progress = 'Открываем раздел «Студенты»...');
          } else if (action == 'login') {
            throw const FormatException('В БАРС требуется авторизация');
          } else if (action == 'ambiguous') {
            throw const FormatException(
              'Найдено несколько групп с одинаковым названием',
            );
          }
        } on FormatException {
          rethrow;
        } catch (_) {
          // The JS context may disappear during a navigation. Retry safely.
        }
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
      throw const FormatException(
        'Не удалось автоматически открыть список. '
        'Можно продолжить вручную.',
      );
    } catch (error) {
      if (mounted && !_manual) {
        setState(() {
          _manual = true;
          _error = error.toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _autoRunning = false);
    }
  }

  /// Extract the real student table only; never use the general-page table
  /// of staff responsible for university journals.
  String _rosterScript() => r'''
    (function () {
      const expected = __GROUP__;
      const clean = s => String(s || '').replace(/\u00a0/g, ' ')
        .replace(/\s+/g, ' ').trim();
      const norm = s => clean(s).toUpperCase()
        .replace(/[AА](?=-\d)/g, 'А').replace(/[–—−]/g, '-');
      if (!norm(document.body?.innerText).includes(norm(expected))) {
        return JSON.stringify({error: 'Открыта не та учебная группа'});
      }
      const tables = Array.from(document.querySelectorAll('table'))
        .filter(table => {
          if (table.getClientRects().length === 0) return false;
          const cols = Array.from(table.querySelectorAll('th'))
            .map(x => clean(x.innerText).toLowerCase());
          return cols.some(x => x === 'фио' || x.includes('ф.и.о')) &&
            cols.some(x => x.includes('статус обучения'));
        });
      if (tables.length !== 1) return JSON.stringify({action: 'wait'});
      const table = tables[0];
      const columns = Array.from(table.querySelectorAll('thead th'))
        .map(x => clean(x.innerText).toLowerCase());
      const fio = columns.findIndex(x => x === 'фио' ||
        x.includes('ф.и.о'));
      const statusCol = columns.findIndex(x =>
        x.includes('статус обучения'));
      if (fio < 0 || statusCol < 0) {
        return JSON.stringify({action: 'wait'});
      }
      const students = [], seen = new Set();
      for (const tr of table.querySelectorAll('tbody tr')) {
        if (tr.getClientRects().length === 0) continue;
        const cells = Array.from(tr.querySelectorAll(':scope > td'));
        if (cells.length <= Math.max(fio, statusCol)) continue;
        const fullName = clean(cells[fio].innerText);
        const status = clean(cells[statusCol].innerText).toLowerCase();
        if (!status.includes('обучается') &&
            !status.includes('допущен к обучению')) continue;
        if (fullName.length > 120 ||
            !/^[\p{L} .'-]+$/u.test(fullName) ||
            fullName.split(' ').filter(Boolean).length < 2) {
          return JSON.stringify({error: 'Неверное ФИО в списке БАРС'});
        }
        if (seen.has(fullName.toLowerCase())) {
          return JSON.stringify({error:
            'Одинаковые ФИО: требуется уникальный идентификатор'});
        }
        seen.add(fullName.toLowerCase());
        let id = null;
        for (const a of cells[fio].querySelectorAll('a[href]')) {
          try {
            const url = new URL(a.getAttribute('href'), location.href);
            if (url.origin !== 'https://bars.mpei.ru') continue;
            id = ['studentID', 'studentId', 'stID', 'studID']
              .map(key => url.searchParams.get(key)).find(Boolean) || null;
            if (id) break;
          } catch (_) {}
        }
        students.push({
          fullName,
          ...(id && /^[A-Za-z0-9_-]{1,120}$/.test(id)
            ? {sourceId: id} : {}),
        });
      }
      if (!students.length) return JSON.stringify({action: 'wait'});

      const panel = table.closest('.panel, .card, .box, .dataTables_wrapper') ||
        table.parentElement?.parentElement?.parentElement || document.body;
      const pagerText = clean(panel.innerText);
      const countMatch = pagerText.match(
        /Отображены\s*\d+\s*[-–]\s*\d+\s*запис[ьи]?\s*из\s*(\d+)/i) ||
        pagerText.match(/из\s+(\d+)\s+запис[ьи]/i);
      const total = countMatch ? Number(countMatch[1]) : null;
      const selects = Array.from(document.querySelectorAll('select'))
        .filter(sel => {
          const opt = Array.from(sel.options);
          return opt.some(o => o.value === '10' || clean(o.text) === '10') &&
            opt.some(o => Number(o.value) >= 50 ||
              Number(clean(o.text)) >= 50);
        });
      const select = selects.length === 1 ? selects[0] : null;
      if (select && (total === null || students.length < total)) {
        const options = Array.from(select.options)
          .filter(o => Number(o.value) >= 50 || Number(clean(o.text)) >= 50)
          .sort((a, b) => Number(b.value || clean(b.text)) -
            Number(a.value || clean(a.text)));
        if (options.length && select.value !== options[0].value) {
          select.value = options[0].value;
          select.dispatchEvent(new Event('change', {bubbles: true}));
          return JSON.stringify({action: 'expand'});
        }
      }
      // Never import a known partial page, even if pagination is still
      // loading asynchronously.
      if (total !== null && students.length < total) {
        return JSON.stringify({action: 'wait'});
      }
      if (total === null && students.length === 10 && selects.length) {
        return JSON.stringify({error:
          'Не удалось проверить полноту списка. Выбери все записи.'});
      }
      return JSON.stringify({action: 'ready', students, total});
    })()
  '''.replaceFirst('__GROUP__', jsonEncode(widget.group));

  Future<bool> _extractRoster() async {
    final result = await _runJson(_rosterScript());
    if (result['action'] == 'wait' || result['action'] == 'expand') return false;
    if (result['error'] is String) {
      throw FormatException(result['error'] as String);
    }
    if (result['action'] != 'ready') return false;
    final rows = result['students'];
    if (rows is! List || rows.length < 3 || rows.length > 120) {
      throw const FormatException(
        'Проверь полноту списка группы (от 3 до 120 студентов)',
      );
    }
    final students = <BarsRosterStudent>[];
    for (final row in rows) {
      if (row is! Map || row['fullName'] is! String) {
        throw const FormatException('Некорректная строка студентов');
      }
      students.add(BarsRosterStudent(
        fullName: (row['fullName'] as String).trim(),
        sourceId: row['sourceId']?.toString(),
      ));
    }
    if (mounted) setState(() {
      _preview = students;
      _error = null;
      _progress = 'Список загружен. Проверь ФИО.';
    });
    return true;
  }

  Future<void> _readVisibleRoster() async {
    if (_busy || _loading || _autoRunning) return;
    if (!await _onBars()) {
      if (mounted) setState(() => _error = 'Открой страницу БАРС');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (!await _extractRoster() && mounted) {
        setState(() => _error =
            'Таблица ещё загружается. Повтори через несколько секунд.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString()
          .replaceFirst('FormatException: ', '')
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
              Text(preview != null
                  ? 'Проверь ФИО перед сохранением.'
                  : _manual
                      ? 'Автоматический переход не завершился. '
                        'Можешь открыть вкладку вручную.'
                      : _progress),
              if (_loading || _autoRunning)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
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
          Expanded(child: IgnorePointer(
            ignoring: !_manual,
            child: WebViewWidget(controller: _web),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_manual)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('bars-read-roster'),
                    onPressed: _busy || _loading || _autoRunning
                        ? null : _readVisibleRoster,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Считать открытый список'),
                  ),
                ),
              if (!_manual)
                OutlinedButton.icon(
                  key: const ValueKey('bars-manual-mode'),
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Открыть вручную'),
                ),
              if (_manual)
                TextButton.icon(
                  key: const ValueKey('bars-auto-retry'),
                  onPressed: _loading || _busy ? null : () {
                    setState(() {
                      _manual = false;
                      _error = null;
                      _progress = 'Открываем учебные группы БАРС...';
                    });
                    _web.loadRequest(Uri.parse(
                      'https://bars.mpei.ru/bars_web/SG/StudyGroup/ListStudyGroup',
                    ));
                  },
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Повторить автоматически'),
                ),
            ]),
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
