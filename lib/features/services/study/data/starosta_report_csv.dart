import '/features/schedule/data/attendance_api.dart';

/// Excel-compatible UTF-8 CSV with BOM and neutralized spreadsheet formulas.
/// Export contains only data visible to this verified headman.
String starostaReportCsv(String group, List<AttendanceReportRow> rows) {
  String cell(String raw) {
    var value = raw.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (RegExp(r'^\s*[=+\-@\t]').hasMatch(value)) value = "'" + value;
    return '"' + value.replaceAll('"', '""') + '"';
  }

  String row(List<String> values) => values.map(cell).join(';') + '\r\n';

  final data = StringBuffer('\uFEFF');
  data.write(row([
    'Группа', 'Дата', 'Время', 'Предмет',
    'Тип занятия', 'Аудитория', 'Студент', 'Отметка',
  ]));
  for (final mark in rows) {
    final label = switch (mark.status) {
      'present' => 'Присутствует',
      'absent' => 'Н',
      'excused' => 'Уважительная причина',
      'pending' => 'Ожидает',
      'rejected' => 'Отклонено',
      _ => 'Не отмечен',
    };
    data.write(row([
      group, mark.date, mark.time, mark.subject,
      mark.type, mark.room, mark.displayName, label,
    ]));
  }
  return data.toString();
}
