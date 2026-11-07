import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/services/study/data/study_activity_storage.dart';
import 'package:campusapp/features/services/study/view/study_results_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudyActivityEntry attempt(
    String id,
    DateTime at,
    int correct,
    int total,
  ) => StudyActivityEntry(
        attemptId: id,
        completedAt: at,
        correctAnswers: correct,
        totalAnswers: total,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('multiple attempts on the same day add correct answers', () {
    final daily = aggregateStudyActivity([
      attempt('a', DateTime(2026, 11, 7, 9), 2, 3),
      attempt('b', DateTime(2026, 11, 7, 20), 5, 6),
      attempt('c', DateTime(2026, 11, 8, 10), 1, 2),
    ]);
    final day = daily[DateTime(2026, 11, 7)]!;
    expect(day.correctAnswers, 7);
    expect(day.totalAnswers, 9);
    expect(day.tests, 2);
    expect(daily[DateTime(2026, 11, 8)]!.correctAnswers, 1);
  });

  test('completed attempts are stored and restored', () async {
    final store = StudyActivityStorage();
    await store.recordAttempt(
      attempt('one', DateTime(2026, 11, 7, 12), 3, 4),
    );
    final restored = await StudyActivityStorage().loadEntries();
    expect(restored, hasLength(1));
    expect(restored.single.correctAnswers, 3);
    expect(restored.single.totalAnswers, 4);
  });

  test('re-saving the same attempt does not double count', () async {
    final store = StudyActivityStorage();
    final entry = attempt('one', DateTime.now(), 2, 2);
    await store.recordAttempt(entry);
    await store.recordAttempt(entry);
    final daily = await store.loadByDay();
    final stats = daily[studyCalendarDay(DateTime.now())]!;
    expect(stats.tests, 1);
    expect(stats.correctAnswers, 2);
  });

  test('streak counts consecutive test days, including yesterday', () {
    final daily = aggregateStudyActivity([
      attempt('a', DateTime(2026, 11, 5), 1, 2),
      attempt('b', DateTime(2026, 11, 6), 3, 3),
      attempt('c', DateTime(2026, 11, 7), 0, 3),
    ]);
    expect(studyCurrentStreak(daily, today: DateTime(2026, 11, 7)), 3);
    expect(studyCurrentStreak(daily, today: DateTime(2026, 11, 8)), 3);
    expect(studyCurrentStreak(daily, today: DateTime(2026, 11, 9)), 0);
  });

  test('invalid results are not accepted', () {
    final raw = {
      'attemptId': 'a',
      'completedAt': '2026-11-07T12:00:00',
      'correctAnswers': 6,
      'totalAnswers': 5,
    };
    expect(StudyActivityEntry.fromJson(raw), isNull);
  });

  test('corrupt history reports an error instead of deleting it', () async {
    SharedPreferences.setMockInitialValues({
      'campus_study_activity_v1': '{invalid',
    });
    await expectLater(
      StudyActivityStorage().loadEntries(),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('quiz results fit a narrow Android screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Тест')),
          body: StudyResultsContent(
            correctAnswers: 2,
            totalAnswers: 2,
            activity: const {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Тест завершён'), findsOneWidget);
    expect(find.text('2 из 2 верно'), findsOneWidget);
    expect(find.text('Активность'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
