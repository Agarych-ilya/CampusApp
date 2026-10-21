class BarsControl {
  const BarsControl({
    required this.title,
    required this.weight,
    required this.deadline,
    required this.grade,
  });

  final String title;
  final String weight;
  final String deadline;
  final String grade;

  factory BarsControl.fromMap(Map<String, dynamic> map) {
    return BarsControl(
      title: map['title']?.toString() ?? '',
      weight: map['weight']?.toString() ?? '',
      deadline: map['deadline']?.toString() ?? '',
      grade: map['grade']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'weight': weight,
      'deadline': deadline,
      'grade': grade,
    };
  }
}
