class BarsStudent {
  final String? id;
  final String fullName;
  final String? group;
  final String? institute;
  final String? course;

  const BarsStudent({
    this.id,
    required this.fullName,
    this.group,
    this.institute,
    this.course,
  });

  factory BarsStudent.fromJson(Map<String, dynamic> json) {
    return BarsStudent(
      id: json['id']?.toString(),
      fullName: json['fullName']?.toString() ?? '',
      group: json['group']?.toString(),
      institute: json['institute']?.toString(),
      course: json['course']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'group': group,
      'institute': institute,
      'course': course,
    };
  }
}
