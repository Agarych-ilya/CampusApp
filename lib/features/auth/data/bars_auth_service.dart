import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BarsAuthService {
  const BarsAuthService();

  Future<bool> hasStudentsLink(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  try {
    return document.querySelector(
      'a[href="/bars_web/ST/Student/ListStudent"]'
    ) !== null;
  } catch (_) {
    return false;
  }
})();
''');

      return _toBool(result);
    } catch (_) {
      return false;
    }
  }

  Future<bool> clickStudents(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  try {
    const link = document.querySelector(
      'a[href="/bars_web/ST/Student/ListStudent"]'
    );

    if (!link) {
      return false;
    }

    link.click();

    return true;
  } catch (_) {
    return false;
  }
})();
''');

      return _toBool(result);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStudentRow(
    WebViewController controller,
  ) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  try {
    const clean = (value) => {
      return (value || '')
        .replace(/\u00A0/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    };

    const result = {
      found: false,
      fullName: '',
      recordBook: '',
      group: ''
    };

    const table =
      document.querySelector(
        '#tbl__PartialListStudent'
      );

    if (!table) {
      return JSON.stringify(result);
    }

    const link =
      table.querySelector(
        'tbody a[href*="/ST/Student/Main?studentID="]'
      );

    if (!link) {
      return JSON.stringify(result);
    }

    const row =
      link.closest('tr');

    if (!row) {
      return JSON.stringify(result);
    }

    const cells =
      Array.from(
        row.querySelectorAll('td')
      );

    result.found = true;
    result.fullName =
      clean(link.textContent);

    if (cells.length >= 4) {
      result.recordBook =
        clean(cells[1].textContent);

      result.group =
        clean(cells[3].textContent);
    }

    return JSON.stringify(result);
  } catch (_) {
    return JSON.stringify({
      found: false
    });
  }
})();
''');

      return _decodeMap(result);
    } catch (_) {
      return null;
    }
  }

  Future<bool> clickStudentName(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  try {
    const link =
      document.querySelector(
        '#tbl__PartialListStudent tbody a[href*="/ST/Student/Main?studentID="]'
      );

    if (!link) {
      return false;
    }

    link.click();

    return true;
  } catch (_) {
    return false;
  }
})();
''');

      return _toBool(result);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStudyHeader(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  const header =
    document.querySelector(
      '#div-FormHeader'
    );

  return !!header &&
    (header.innerText || '').trim().length > 0;
})();
''');

      return _toBool(result);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> extractStudyProfile(
    WebViewController controller,
  ) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  try {
    const clean = (value) => {
      return (value || '')
        .replace(/\u00A0/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    };

    const result = {
      ready: false,
      fullName: '',
      recordBook: '',
      group: '',
      email: '',
      course: '',
      educationLevel: ''
    };

    const header =
      document.querySelector(
        '#div-FormHeader'
      );

    if (!header) {
      return JSON.stringify(result);
    }

    const spans =
      Array.from(
        header.querySelectorAll(
          'span.fw-bold'
        )
      );

    for (const span of spans) {
      const text =
        clean(span.textContent);

      if (
        text.includes('№ЗК') ||
        text.includes('№ ЗК')
      ) {
        const match =
          text.match(
            /^(.+?)\s*\(\s*№\s*ЗК\s*[-–—:]?\s*([^)]+)\)/i
          );

        if (match) {
          result.fullName =
            clean(match[1]);

          result.recordBook =
            clean(match[2]);
        }
      }
    }

    const scheduleLink =
      header.querySelector(
        'a[href*="/Open/RUZ/Timetable"][href*="rt=3"]'
      );

    if (scheduleLink) {
      try {
        const url =
          new URL(
            scheduleLink.getAttribute(
              'href'
            ),
            window.location.origin
          );

        result.group =
          clean(
            url.searchParams.get(
              'name'
            )
          );
      } catch (_) {}
    }

    const mail =
      header.querySelector(
        'a[href^="mailto:"]'
      );

    if (mail) {
      result.email =
        clean(
          (
            mail.getAttribute(
              'href'
            ) || ''
          ).replace(
            /^mailto:/i,
            ''
          )
        );
    }

    const items =
      Array.from(
        header.querySelectorAll(
          'li.list-inline-item'
        )
      );

    for (const item of items) {
      const text =
        clean(item.textContent);

      const lower =
        text.toLowerCase();

      const strong =
        item.querySelector(
          'strong'
        );

      if (!strong) {
        continue;
      }

      const value =
        clean(
          strong.textContent
        );

      if (
        lower.startsWith(
          'курс:'
        )
      ) {
        result.course =
          value;
      }

      if (
        lower.startsWith(
          'уровень образования:'
        )
      ) {
        result.educationLevel =
          value;
      }
    }

    result.ready =
      result.group !== '';

    return JSON.stringify(result);
  } catch (_) {
    return JSON.stringify({
      ready: false
    });
  }
})();
''');

      return _decodeMap(result);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ВСЕ ПРЕДМЕТЫ ИЗ "ОЦЕНКИ В БАРС"
  // ============================================================

  // Load subjects from the authenticated BARS page.
  //
  // Android WebView does not reliably await a Promise returned from
  // runJavaScriptReturningResult. Start the job synchronously in the page,
  // let it fetch previous semesters, then poll its explicit state.
  Future<List<Map<String, dynamic>>> extractSubjects(
    WebViewController controller,
  ) async {
    const pause = Duration(milliseconds: 250);

    try {
      // The study header can appear before the marks fragment has loaded.
      var ready = false;
      for (var attempt = 0; attempt < 40; attempt++) {
        final result = await controller.runJavaScriptReturningResult(r'''
(() => Boolean(
  document.querySelector('#ddl_StudyFilterSemester') &&
  document.querySelector('#div-Student_SemesterSheet__Mark [data-bs-target^="#s_ss_"]')
))();
''');
        if (_toBool(result)) {
          ready = true;
          break;
        }
        await Future<void>.delayed(pause);
      }

      if (!ready) {
        debugPrint('BARS SUBJECTS: marks fragment not ready');
        return [];
      }

      // This script only reads the currently authenticated, same-origin
      // study page. It never exports session credentials to Campus backend.
      await controller.runJavaScript(r'''
(() => {
  const clean = value => (value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const job = {
    status: 'running',
    subjects: [],
    currentCount: 0,
    semesters: 0,
    processed: 0,
    failed: 0
  };
  window.__campusBarsSubjectsJob = job;

  const parseSemester = (html, semester) => {
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const subjects = [];
    const seen = new Set();

    for (const header of doc.querySelectorAll('[data-bs-target^="#s_ss_"]')) {
      const target = header.getAttribute('data-bs-target') || '';
      if (!/^#s_ss_\d+$/.test(target) || seen.has(target)) continue;
      seen.add(target);

      const panel = doc.getElementById(target.slice(1));
      if (!panel) continue;

      const headerClone = header.cloneNode(true);
      headerClone.querySelectorAll('.badge, button, .btn').forEach(x => x.remove());
      const parts = clean(headerClone.textContent).split(',').map(clean).filter(Boolean);
      if (!parts.length) continue;

      // The subject itself may contain commas (e.g. "..., часть 2").
      const name = parts.length >= 4
        ? clean(parts.slice(0, -3).join(', '))
        : parts[0];
      if (!name) continue;

      const attestation = parts.find(x =>
        /экзамен|зачёт|зачет|диф\.?\s*зач/i.test(x)
      ) || '';
      const credits = parts.find(x => /\d+\s*зе\b/i.test(x)) || '';

      const subject = {
        name,
        semester,
        attestation,
        credits,
        currentScore: '',
        finalGrade: '',
        controls: []
      };

      for (const row of panel.querySelectorAll('table tbody tr')) {
        if (row.id && row.id.startsWith('divMERes')) continue;
        const cells = Array.from(row.children).filter(x => x.tagName === 'TD');
        if (!cells.length) continue;

        const first = clean(cells[0].textContent).toLowerCase();
        const last = clean(cells[cells.length - 1].textContent);

        if (first.includes('балл текущего контроля')) {
          subject.currentScore = last;
          continue;
        }
        if (first.includes('итоговая оценка')) {
          subject.finalGrade = last;
          continue;
        }
        if (first.includes('промежуточная аттестация') ||
            first.includes('контрольная неделя') ||
            first.includes('текущий контроль')) continue;

        if (cells.length !== 4 || cells[0].hasAttribute('colspan')) continue;

        const titleClone = cells[0].cloneNode(true);
        titleClone.querySelectorAll('button, .btn, [data-bs-target^="#divMERes"]')
          .forEach(x => x.remove());
        const title = clean(titleClone.textContent).replace(/^\d+\.\s*/, '');
        if (!title) continue;

        const gradeClone = cells[3].cloneNode(true);
        // A previous mark after a retake is not the current grade.
        gradeClone.querySelectorAll('.km-retaken').forEach(x => x.remove());

        subject.controls.push({
          title,
          weight: clean(cells[1].textContent),
          deadline: clean(cells[2].textContent),
          grade: clean(gradeClone.textContent)
        });
      }
      subjects.push(subject);
    }
    return subjects;
  };

  // Run the async work without returning a Promise to Android WebView.
  const run = async () => {
    try {
      const root = document.querySelector('#div-Student_SemesterSheet__Mark');
      const select = document.querySelector('#ddl_StudyFilterSemester');
      if (!root || !select) throw new Error('marks fragment not ready');

      const currentOption = select.options[select.selectedIndex];
      const currentName = currentOption ? clean(currentOption.textContent) : '';
      job.subjects.push(...parseSemester(root.outerHTML, currentName));
      job.currentCount = job.subjects.length;

      const studentID = new URL(window.location.href).searchParams.get('studentID');
      if (!studentID) throw new Error('study page identifier unavailable');

      const semesters = Array.from(select.options)
        .map(x => ({ id: clean(x.value), name: clean(x.textContent) }))
        .filter(x => /^\d+$/.test(x.id) && x.id !== clean(select.value));
      job.semesters = semesters.length;

      // Limit concurrent same-origin requests to avoid overloading BARS.
      let next = 0;
      const worker = async () => {
        while (next < semesters.length) {
          const semester = semesters[next++];
          try {
            const query = { ID: studentID, FilterSemester: { Value: semester.id } };
            const params = new URLSearchParams({
              studentID: studentID,
              query: JSON.stringify(query)
            });
            const url = '/bars_web/ST_Study/Student_SemesterSheet/' +
              '_PartialListStudent_SemesterSheet__Mark?' + params.toString();
            const response = await fetch(url, {
              method: 'GET',
              credentials: 'same-origin',
              cache: 'no-store',
              headers: { 'X-Requested-With': 'XMLHttpRequest' }
            });
            if (!response.ok) throw new Error('semester unavailable');
            const html = await response.text();
            const parsed = parseSemester(html, semester.name);
            if (parsed.length) job.subjects.push(...parsed);
            else job.failed++;
          } catch (_) {
            job.failed++;
          } finally {
            job.processed++;
          }
        }
      };

      await Promise.all([worker(), worker()]);
      job.status = 'complete';
    } catch (_) {
      job.status = 'error';
    }
  };

  void run();
})();
''');

      // Wait for the job, but retain any current-semester data on timeout.
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      Map<String, dynamic>? state;

      do {
        await Future<void>.delayed(pause);
        final result = await controller.runJavaScriptReturningResult(r'''
(() => {
  const job = window.__campusBarsSubjectsJob;
  if (!job) return JSON.stringify({ status: 'missing', subjects: [] });
  return JSON.stringify({
    status: job.status,
    subjects: job.status === 'running' ? [] : job.subjects,
    currentCount: job.currentCount,
    semesters: job.semesters,
    processed: job.processed,
    failed: job.failed
  });
})();
''');
        state = _decodeMap(result);
        if (state?['status'] == 'complete' ||
            state?['status'] == 'error' ||
            state?['status'] == 'missing') {
          break;
        }
      } while (DateTime.now().isBefore(deadline));

      // A timeout must not throw away the current semester.
      if (state?['status'] == 'running') {
        final result = await controller.runJavaScriptReturningResult(r'''
(() => JSON.stringify({
  status: 'partial',
  subjects: window.__campusBarsSubjectsJob?.subjects || [],
  currentCount: window.__campusBarsSubjectsJob?.currentCount || 0,
  processed: window.__campusBarsSubjectsJob?.processed || 0,
  failed: window.__campusBarsSubjectsJob?.failed || 0
}))();
''');
        state = _decodeMap(result);
      }

      final subjects = <Map<String, dynamic>>[];
      final items = state?['subjects'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            subjects.add(Map<String, dynamic>.from(item));
          }
        }
      }

      debugPrint(
        'BARS SUBJECTS: status=' + (state?['status']).toString() +
        ', current=' + (state?['currentCount']).toString() +
        ', semesters=' + (state?['processed']).toString() +
        '/' + (state?['semesters']).toString() +
        ', failed=' + (state?['failed']).toString() +
        ', count=' + subjects.length.toString(),
      );
      return subjects;
    } catch (e) {
      debugPrint('BARS SUBJECTS: loading failed');
      return [];
    }
  }

  bool _toBool(Object value) {
    final text = value.toString().replaceAll('"', '').trim().toLowerCase();

    return text == 'true';
  }

  Map<String, dynamic>? _decodeMap(Object result) {
    try {
      dynamic decoded = jsonDecode(result.toString());

      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  List<Map<String, dynamic>> _decodeList(Object result) {
    try {
      dynamic decoded = jsonDecode(result.toString());

      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is! List) {
        return [];
      }

      final resultList = <Map<String, dynamic>>[];

      for (final item in decoded) {
        if (item is Map) {
          resultList.add(Map<String, dynamic>.from(item));
        }
      }

      return resultList;
    } catch (_) {
      return [];
    }
  }
}
