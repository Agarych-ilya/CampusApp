import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/services/study/data/study_activity_storage.dart';
import 'package:campusapp/features/services/study/view/study_results_screen.dart';
import 'package:campusapp/features/services/study/widgets/study_activity_heatmap.dart';
import 'package:campusapp/features/services/study/data/study_deck.dart';
import 'package:campusapp/features/services/study/view/study_session_screen.dart';

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

  test('flashcard rounds contribute to intensity without being counted as quizzes', () async {
    final store = StudyActivityStorage();
    final today = DateTime.now();
    await store.recordAttempt(StudyActivityEntry(
      attemptId: 'flashcards-test-1',
      completedAt: today,
      correctAnswers: 2,
      totalAnswers: 2,
      kind: 'flashcards',
    ));
    await store.recordAttempt(StudyActivityEntry(
      attemptId: 'flashcards-test-2',
      completedAt: today,
      correctAnswers: 1,
      totalAnswers: 2,
      kind: 'flashcards',
    ));
    await store.recordAttempt(StudyActivityEntry(
      attemptId: 'quiz-test-1',
      completedAt: today,
      correctAnswers: 2,
      totalAnswers: 2,
    ));
    final activity = (await store.loadByDay())[studyCalendarDay(today)]!;
    expect(activity.correctAnswers, 5);
    expect(activity.tests, 1);
    expect(activity.flashcardRounds, 2);
    expect(activity.sessions, 3);
  });

  test('previous quiz results without kind remain readable', () {
    final original = StudyActivityEntry.fromJson({
      'attemptId': 'old-quiz',
      'completedAt': DateTime(2026, 11, 8).toIso8601String(),
      'correctAnswers': 3,
      'totalAnswers': 4,
    });
    expect(original?.kind, 'quiz');
  });

  testWidgets('finishing flashcards records a full round once', (tester) async {
    final deck = StudyDeck(
      id: 'test-flashcards',
      title: 'Пример',
      description: '',
      cards: const [
        StudyCard(id: 'c1', term: 'Первый', definition: 'Ответ один'),
        StudyCard(id: 'c2', term: 'Второй', definition: 'Ответ два'),
      ],
      knownCardIds: const {},
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyFlashcardsScreen(
          deck: deck,
          onChanged: (updated) async {},
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Показать ответ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Знаю'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Круг завершён!'), findsOneWidget);
    final saved = await StudyActivityStorage().loadEntries();
    expect(saved, hasLength(1));
    expect(saved.single.kind, 'flashcards');
    expect(saved.single.correctAnswers, 2);
    expect(saved.single.totalAnswers, 2);
    expect((await StudyActivityStorage().loadByDay())
        [studyCalendarDay(DateTime.now())]!.flashcardRounds, 1);
  });

  testWidgets('activity displays exactly 17 calendar weeks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudyActivityHeatmap(activity: {}),
        ),
      ),
    );
    expect(StudyActivityHeatmap.semesterWeeks, 17);
    expect(find.byKey(const ValueKey('semester-week-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('semester-week-16')), findsOneWidget);
    expect(find.byKey(const ValueKey('semester-week-17')), findsNothing);
    expect(find.text('Активность · 17 недель'), findsOneWidget);
    expect(find.text('7 дней'), findsNothing);
    expect(find.text('30 дней'), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Активность · 17 недель'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
