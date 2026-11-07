import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One completed quiz attempt; its ID prevents double counting on retries.
class StudyActivityEntry {
  const StudyActivityEntry({
    required this.attemptId,
    required this.completedAt,
    required this.correctAnswers,
    required this.totalAnswers,
  });

  final String attemptId;
  final DateTime completedAt;
  final int correctAnswers;
  final int totalAnswers;

  Map<String, dynamic> toJson() => {
        'attemptId': attemptId,
        'completedAt': completedAt.toIso8601String(),
        'correctAnswers': correctAnswers,
        'totalAnswers': totalAnswers,
      };

  static StudyActivityEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['attemptId'];
    final timestamp = raw['completedAt'];
    final correct = raw['correctAnswers'];
    final total = raw['totalAnswers'];
    final completed = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (id is! String ||
        id.isEmpty ||
        completed == null ||
        correct is! int ||
        total is! int ||
        total < 1 ||
        total > 1000 ||
        correct < 0 ||
        correct > total) {
      return null;
    }
    return StudyActivityEntry(
      attemptId: id,
      completedAt: completed.toLocal(),
      correctAnswers: correct,
      totalAnswers: total,
    );
  }
}

class StudyDayActivity {
  const StudyDayActivity({
    this.correctAnswers = 0,
    this.totalAnswers = 0,
    this.tests = 0,
  });

  final int correctAnswers;
  final int totalAnswers;
  final int tests;

  StudyDayActivity add(StudyActivityEntry entry) => StudyDayActivity(
        correctAnswers: correctAnswers + entry.correctAnswers,
        totalAnswers: totalAnswers + entry.totalAnswers,
        tests: tests + 1,
      );
}

/// All dates use the device's local calendar day (not UTC midnight).
DateTime studyCalendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Map<DateTime, StudyDayActivity> aggregateStudyActivity(
  Iterable<StudyActivityEntry> entries,
) {
  final byDay = <DateTime, StudyDayActivity>{};
  for (final entry in entries) {
    final day = studyCalendarDay(entry.completedAt.toLocal());
    byDay[day] = (byDay[day] ?? const StudyDayActivity()).add(entry);
  }
  return byDay;
}

/// Consecutive days with completed tests; yesterday may start the streak.
int studyCurrentStreak(
  Map<DateTime, StudyDayActivity> byDay, {
  DateTime? today,
}) {
  var date = studyCalendarDay(today ?? DateTime.now());
  if ((byDay[date]?.tests ?? 0) == 0) {
    date = DateTime(date.year, date.month, date.day - 1);
  }
  var streak = 0;
  while ((byDay[date]?.tests ?? 0) > 0) {
    streak++;
    date = DateTime(date.year, date.month, date.day - 1);
  }
  return streak;
}

/// Device-only quiz history. Data is not uploaded to the server.
class StudyActivityStorage {
  static const _key = 'campus_study_activity_v1';

  Future<List<StudyActivityEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Неверный формат истории тестов');
    }
    final entries = <StudyActivityEntry>[];
    for (final item in decoded) {
      final entry = StudyActivityEntry.fromJson(item);
      if (entry == null) {
        throw const FormatException('Неверная запись истории тестов');
      }
      entries.add(entry);
    }
    return entries;
  }

  Future<void> recordAttempt(StudyActivityEntry attempt) async {
    if (StudyActivityEntry.fromJson(attempt.toJson()) == null) {
      throw const FormatException('Неверный результат теста');
    }
    final entries = await loadEntries();
    if (entries.any((entry) => entry.attemptId == attempt.attemptId)) {
      return;
    }
    // Keep a year of completed attempts, with a bounded storage size.
    final oldest = DateTime.now().subtract(const Duration(days: 365));
    final updated = <StudyActivityEntry>[
      ...entries.where((entry) => !entry.completedAt.isBefore(oldest)),
      attempt,
    ]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final trimmed = updated.length > 5000
        ? updated.sublist(updated.length - 5000)
        : updated;

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key,
      jsonEncode(trimmed.map((entry) => entry.toJson()).toList()),
    );
    if (!saved) throw const FormatException('Не удалось сохранить историю');
  }

  Future<Map<DateTime, StudyDayActivity>> loadByDay() async =>
      aggregateStudyActivity(await loadEntries());
}
