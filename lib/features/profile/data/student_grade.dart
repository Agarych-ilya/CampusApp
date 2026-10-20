class StudentGrade {
  const StudentGrade({
    required this.subject,
    required this.control,
    required this.grade,
    required this.date,
    required this.semester,
  });

  final String subject;
  final String control;
  final String grade;
  final String date;
  final String semester;

  factory StudentGrade.fromMap(Map<String, dynamic> map) {
    return StudentGrade(
      subject: map['subject']?.toString() ?? '',
      control: map['control']?.toString() ?? '',
      grade: map['grade']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      semester: map['semester']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'control': control,
      'grade': grade,
      'date': date,
      'semester': semester,
    };
  }
}
