class StudentProfile {
  const StudentProfile({
    required this.fullName,
    required this.group,
    required this.recordBook,
    required this.course,
    required this.educationLevel,
    required this.email,
    required this.faculty,
  });

  final String fullName;
  final String group;
  final String recordBook;
  final String course;
  final String educationLevel;
  final String email;
  final String faculty;

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      fullName: (map['fullName'] ?? '').toString().trim(),
      group: (map['group'] ?? '').toString().trim(),
      recordBook: (map['recordBook'] ?? '').toString().trim(),
      course: (map['course'] ?? '').toString().trim(),
      educationLevel: (map['educationLevel'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      faculty: (map['faculty'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'group': group,
      'recordBook': recordBook,
      'course': course,
      'educationLevel': educationLevel,
      'email': email,
      'faculty': faculty,
    };
  }
}
