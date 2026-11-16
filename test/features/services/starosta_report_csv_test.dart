import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/schedule/data/attendance_api.dart';
import 'package:campusapp/features/services/study/data/starosta_report_csv.dart';

void main() {
  test('CSV export includes only the filtered student rows and BOM', () {
    final data = starostaReportCsv('А-03-23', const [
      AttendanceReportRow(
        date:'2026-11-16',time:'10:15',subject:'ТАУ',
        type:'Практика',room:'М-307',displayName:'Иванов Иван',
        ownerKey:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status:'absent',
      ),
    ]);
    expect(data.startsWith('\uFEFF'),isTrue);
    expect(data,contains('"Иванов Иван";"Н"'));
    expect(data,contains('"А-03-23";"2026-11-16"'));
    expect(data.split('\r\n').length,3);
    // Opaque owner-key must never be exported in student-facing documents.
    expect(data, isNot(contains('aaaaaaaaaaaaaaaa')));
  });

  test('untrusted BARS text cannot execute an Excel formula', () {
    final data = starostaReportCsv('А-03-23', const [
      AttendanceReportRow(
        date:'2026-11-16',time:'10:15',subject:'=HYPERLINK("bad")',
        type:'',room:'',displayName:'+SUM(1,1)',
        ownerKey:'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
                 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        status:'present',
      ),
    ]);
    expect(data,contains('"\'=HYPERLINK(""bad"")"'));
    expect(data,contains('"\' +SUM(1,1)"'),isFalse);
    expect(data,contains('"\'+SUM(1,1)"'));
  });
}
