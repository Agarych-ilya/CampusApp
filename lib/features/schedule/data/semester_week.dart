/// One-based semester teaching week: fall begins with the week containing
/// September 1, spring with the week containing February 1.
/// Based on calendar weeks; does not infer university holiday schedules.
int semesterWeekNumber(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final semesterStart = date.month >= 9
      ? DateTime.utc(date.year, 9, 1)
      : date.month >= 2
          ? DateTime.utc(date.year, 2, 1)
          : DateTime.utc(date.year - 1, 9, 1);
  final monday = DateTime.utc(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day - (semesterStart.weekday - 1),
  );
  final selectedMonday = DateTime.utc(
    d.year,
    d.month,
    d.day - (d.weekday - 1),
  );
  return selectedMonday.difference(monday).inDays ~/ 7 + 1;
}

String semesterWeekLabel(DateTime date) =>
    '${semesterWeekNumber(date)} неделя';
