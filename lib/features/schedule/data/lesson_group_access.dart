/// Compare a viewed timetable against the student's BARS profile group.
/// Schedule searching is independent and does not grant lesson details.
String normalizeCampusGroup(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'[–—−]'), '-')
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll('A', 'А');

bool canOpenOwnLessonDetails({
  required String? profileGroup,
  required String? viewedGroup,
}) {
  if (profileGroup == null || viewedGroup == null ||
      profileGroup.trim().isEmpty || viewedGroup.trim().isEmpty) {
    return false;
  }
  return normalizeCampusGroup(profileGroup) == normalizeCampusGroup(viewedGroup);
}
