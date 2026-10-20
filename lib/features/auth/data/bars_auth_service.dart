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

  Future<List<Map<String, dynamic>>> extractSubjects(
    WebViewController controller,
  ) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(async () => {
  try {
    const clean = (value) => {
      return (value || '')
        .replace(/\u00A0/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    };

    const allSubjects = [];

    const currentUrl =
      new URL(
        window.location.href
      );

    const studentID =
      currentUrl.searchParams.get(
        'studentID'
      );

    if (!studentID) {
      return JSON.stringify([]);
    }

    const semesterSelect =
      document.querySelector(
        '#ddl_StudyFilterSemester'
      );

    if (!semesterSelect) {
      return JSON.stringify([]);
    }

    const semesters =
      Array.from(
        semesterSelect.options
      ).map(
        option => ({
          id: clean(
            option.value
          ),
          name: clean(
            option.textContent
          )
        })
      );

    const currentSemesterId =
      clean(
        semesterSelect.value
      );

    // =========================================================
    // ПАРСИНГ HTML ОДНОГО СЕМЕСТРА
    // =========================================================

    const parseSemester = (
      html,
      semesterName
    ) => {
      const parsedSubjects = [];

      const parser =
        new DOMParser();

      const doc =
        parser.parseFromString(
          html,
          'text/html'
        );

      const headers =
        Array.from(
          doc.querySelectorAll(
            '[data-bs-target^="#s_ss_"]'
          )
        );

      const used =
        new Set();

      for (const header of headers) {
        const target =
          header.getAttribute(
            'data-bs-target'
          );

        if (
          !target ||
          used.has(target)
        ) {
          continue;
        }

        used.add(target);

        let container = null;

        try {
          container =
            doc.querySelector(
              target
            );
        } catch (_) {}

        if (!container) {
          continue;
        }

        // =====================================================
        // ЗАГОЛОВОК ПРЕДМЕТА
        // =====================================================

        const clone =
          header.cloneNode(true);

        for (
          const element of
          clone.querySelectorAll(
            '.badge, button, .btn'
          )
        ) {
          element.remove();
        }

        const headerText =
          clean(
            clone.textContent
          );

        if (!headerText) {
          continue;
        }

        const parts =
          headerText
            .split(',')
            .map(clean)
            .filter(Boolean);

        let name =
          parts.length > 0
            ? parts[0]
            : headerText;

        let attestation = '';
        let credits = '';

        for (const part of parts) {
          const lower =
            part.toLowerCase();

          if (
            lower.includes(
              'экзамен'
            ) ||
            lower.includes(
              'зачёт'
            ) ||
            lower.includes(
              'зачет'
            )
          ) {
            attestation =
              part;
          }

          if (
            /зе/i.test(part)
          ) {
            credits =
              part;
          }
        }

        const controls = [];

        let currentScore = '';
        let finalGrade = '';

        const rows =
          Array.from(
            container.querySelectorAll(
              'table tbody tr'
            )
          );

        for (const row of rows) {
          if (
            row.id &&
            row.id.startsWith(
              'divMERes'
            )
          ) {
            continue;
          }

          const cells =
            Array.from(
              row.children
            ).filter(
              cell =>
                cell.tagName === 'TD'
            );

          if (
            cells.length === 0
          ) {
            continue;
          }

          const rowText =
            clean(
              row.textContent
            );

          if (!rowText) {
            continue;
          }

          const lower =
            rowText.toLowerCase();

          // ===============================================
          // БАЛЛ ТЕКУЩЕГО КОНТРОЛЯ
          // ===============================================

          if (
            lower.includes(
              'балл текущего контроля'
            )
          ) {
            currentScore =
              clean(
                cells[
                  cells.length - 1
                ].textContent
              );

            continue;
          }

          // ===============================================
          // ИТОГОВАЯ ОЦЕНКА
          // ===============================================

          if (
            lower.includes(
              'итоговая оценка'
            )
          ) {
            finalGrade =
              clean(
                cells[
                  cells.length - 1
                ].textContent
              );

            continue;
          }

          // ===============================================
          // ПРОМЕЖУТОЧНУЮ АТТЕСТАЦИЮ ОТДЕЛЬНО НЕ ДОБАВЛЯЕМ
          // ===============================================

          if (
            lower.includes(
              'промежуточная аттестация'
            )
          ) {
            continue;
          }

          // ===============================================
          // СТРОКИ КОНТРОЛЬНЫХ НЕДЕЛЬ НЕ НУЖНЫ
          // ===============================================

          if (
            lower.includes(
              'контрольная неделя'
            )
          ) {
            continue;
          }

          // ===============================================
          // ЗАГОЛОВОК "ТЕКУЩИЙ КОНТРОЛЬ"
          // ===============================================

          if (
            lower.includes(
              'текущий контроль'
            )
          ) {
            continue;
          }

          // ===============================================
          // ОБЫЧНОЕ КОНТРОЛЬНОЕ МЕРОПРИЯТИЕ
          // ===============================================

          if (
            cells.length !== 4
          ) {
            continue;
          }

          const titleCell =
            cells[0].cloneNode(
              true
            );

          for (
            const element of
            titleCell.querySelectorAll(
              'button, .btn, [data-bs-target^="#divMERes"]'
            )
          ) {
            element.remove();
          }

          let title =
            clean(
              titleCell.textContent
            );

          title =
            title.replace(
              /^\d+\.\s*/,
              ''
            );

          title =
            clean(title);

          const weight =
            clean(
              cells[1].textContent
            );

          const deadline =
            clean(
              cells[2].textContent
            );

          const grade =
            clean(
              cells[3].textContent
            );

          if (!title) {
            continue;
          }

          controls.push({
            title: title,
            weight: weight,
            deadline: deadline,
            grade: grade
          });
        }

        parsedSubjects.push({
          name: name,
          semester:
            semesterName,
          attestation:
            attestation,
          credits:
            credits,
          currentScore:
            currentScore,
          finalGrade:
            finalGrade,
          controls:
            controls
        });
      }

      return parsedSubjects;
    };

    // =========================================================
    // ТЕКУЩИЙ СЕМЕСТР
    // =========================================================

    const currentRoot =
      document.querySelector(
        '#div-Student_SemesterSheet__Mark'
      );

    if (currentRoot) {
      const option =
        semesterSelect.options[
          semesterSelect.selectedIndex
        ];

      const semesterName =
        option
          ? clean(
              option.textContent
            )
          : '';

      const currentSubjects =
        parseSemester(
          currentRoot.outerHTML,
          semesterName
        );

      allSubjects.push(
        ...currentSubjects
      );
    }

    // =========================================================
    // ОСТАЛЬНЫЕ СЕМЕСТРЫ
    // =========================================================

    for (
      const semester of semesters
    ) {
      if (
        semester.id ===
        currentSemesterId
      ) {
        continue;
      }

      try {
        const query = {
          ID: studentID,
          FilterSemester: {
            Value:
              semester.id
          }
        };

        const params =
          new URLSearchParams();

        params.set(
          'studentID',
          studentID
        );

        params.set(
          'query',
          JSON.stringify(
            query
          )
        );

        const response =
          await fetch(
            '/bars_web/ST_Study/Student_SemesterSheet/_PartialListStudent_SemesterSheet__Mark?' +
            params.toString(),
            {
              method: 'GET',
              credentials:
                'same-origin',
              cache:
                'no-store',
              headers: {
                'X-Requested-With':
                  'XMLHttpRequest'
              }
            }
          );

        if (!response.ok) {
          continue;
        }

        const html =
          await response.text();

        const subjects =
          parseSemester(
            html,
            semester.name
          );

        allSubjects.push(
          ...subjects
        );
      } catch (_) {}
    }

    return JSON.stringify(
      allSubjects
    );
  } catch (_) {
    return JSON.stringify([]);
  }
})();
''');

      final subjects = _decodeList(result);

      debugPrint('BARS SUBJECTS: count=${subjects.length}');

      return subjects;
    } catch (e) {
      debugPrint('BARS extractSubjects error: $e');

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
