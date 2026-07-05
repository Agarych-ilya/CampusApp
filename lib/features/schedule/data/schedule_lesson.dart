class ScheduleLesson {
  const ScheduleLesson({
    required this.date,
    required this.time,
    required this.subject,
    required this.type,
    required this.room,
    required this.teacher,
  });

  final String date;
  final String time;
  final String subject;
  final String type;
  final String room;
  final String teacher;

  factory ScheduleLesson.fromJson(Map<String, dynamic> json) {
    return ScheduleLesson(
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      subject: (json['subject'] ?? json['name'])?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      teacher: (json['teacher'] ?? json['pers'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'time': time,
      'subject': subject,
      'type': type,
      'room': room,
      'teacher': teacher,
    };
  }

  DateTime? get parsedDate {
    final match = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(date);

    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);

    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }
}
