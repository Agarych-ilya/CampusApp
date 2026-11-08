import '/features/profile/data/student_grade.dart';
import '/features/profile/data/student_grades_storage.dart';
import '/features/profile/data/bars_subject.dart';
import '/features/profile/data/bars_subjects_storage.dart';

String normalizedLessonSubject(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String? _nonBlank(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

double? _fivePointGrade(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final number = double.tryParse(normalized);
  if (number == null || number < 2 || number > 5) return null;
  return number;
}

/// Personal BARS-derived data only. No group-wide grades are available.
class LessonGradesSummary {
  const LessonGradesSummary({
    required this.average,
    required this.gradeCount,
    required this.gradeLabels,
    this.currentScore,
    this.finalGrade,
    this.semester,
    this.attestation,
  });

  final double? average;
  final int gradeCount;
  final List<String> gradeLabels;
  final String? currentScore;
  final String? finalGrade;
  final String? semester;
  final String? attestation;

  static LessonGradesSummary fromData({
    required String subject,
    required List<StudentGrade> grades,
    required List<BarsSubject> subjects,
  }) {
    final name = normalizedLessonSubject(subject);
    final matches = grades.where(
      (grade) => normalizedLessonSubject(grade.subject) == name,
    ).toList();
    final recorded = matches
        .map((grade) => _fivePointGrade(grade.grade))
        .whereType<double>()
        .toList();

    final subjectMatches = subjects.where(
      (item) => normalizedLessonSubject(item.name) == name,
    ).toList()
      ..sort((a, b) => b.semester.compareTo(a.semester));
    final bars = subjectMatches.isEmpty ? null : subjectMatches.first;

    // A control point can contain points (0..100) rather than marks (2..5).
    // Prefer the grade records; don't double-count controls when grades exist.
    if (recorded.isEmpty && bars != null) {
      recorded.addAll(
        bars.controls.map((item) => _fivePointGrade(item.grade))
            .whereType<double>(),
      );
    }

    return LessonGradesSummary(
      average: recorded.isEmpty
          ? null
          : recorded.reduce((a, b) => a + b) / recorded.length,
      gradeCount: recorded.length,
      gradeLabels: matches.isNotEmpty
          ? matches.map((item) =>
              '${item.control.isEmpty ? 'Оценка' : item.control}: ${item.grade}'
              '${item.date.isEmpty ? '' : ' · ${item.date}'}').toList()
          : bars == null
              ? const []
              : bars.controls.where((item) => item.grade.trim().isNotEmpty)
                  .map((item) => '${item.title}: ${item.grade}').toList(),
      currentScore: _nonBlank(bars?.currentScore),
      finalGrade: _nonBlank(bars?.finalGrade),
      semester: _nonBlank(bars?.semester),
      attestation: _nonBlank(bars?.attestation),
    );
  }

  static Future<LessonGradesSummary> load(String subject) async {
    final grades = await StudentGradesStorage().getGrades();
    final subjects = await BarsSubjectsStorage().getSubjects();
    return fromData(subject: subject, grades: grades, subjects: subjects);
  }
}
