import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/profile/data/student_grade.dart';
import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/schedule/data/lesson_grades_summary.dart';
import 'package:campusapp/features/schedule/data/lesson_group_access.dart';
import 'package:campusapp/features/schedule/data/group_lesson_notes_api.dart';
import 'package:campusapp/features/schedule/view/lesson_details_sheet.dart';
import 'package:campusapp/features/schedule/data/private_lesson_notes_storage.dart';
import 'package:campusapp/features/schedule/data/schedule_lesson.dart';
import 'package:campusapp/features/schedule/widgets/lesson_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const first = ScheduleLesson(
    date: '03.11.2026',
    time: '09:20 - 10:55',
    subject: 'Моделирование систем управления',
    type: 'Лекция',
    room: 'С-409',
    teacher: 'Васильев А.А.',
  );
  const second = ScheduleLesson(
    date: '03.11.2026',
    time: '11:10 - 12:45',
    subject: 'Моделирование систем управления',
    type: 'Практика',
    room: 'С-409',
    teacher: 'Васильев А.А.',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('personal notes remain private to a specific lesson and group', () async {
    final store = PrivateLessonNotesStorage();
    await store.save(
      group: 'А-03-23',
      lesson: first,
      content: 'Подготовить отчёт',
    );
    expect(
      await PrivateLessonNotesStorage().load(
        group: 'А-03-23', lesson: first,
      ),
      'Подготовить отчёт',
    );
    expect(await store.load(group: 'А-03-23', lesson: second), isEmpty);
    expect(await store.load(group: 'А-04-23', lesson: first), isEmpty);
    await store.save(group: 'А-03-23', lesson: first, content: '');
    expect(await store.load(group: 'А-03-23', lesson: first), isEmpty);
  });

  test('only actual 2..5 personal grades contribute to average', () {
    const grades = [
      StudentGrade(
        subject: 'Моделирование систем управления',
        control: 'РК-1',
        grade: '5',
        date: '01.11.2026',
        semester: '7',
      ),
      StudentGrade(
        subject: 'моделирование СИСТЕМ управления',
        control: 'РК-2',
        grade: '4',
        date: '03.11.2026',
        semester: '7',
      ),
      StudentGrade(
        subject: 'Другая дисциплина',
        control: 'Экзамен',
        grade: '2',
        date: '03.11.2026',
        semester: '7',
      ),
      StudentGrade(
        subject: 'Моделирование систем управления',
        control: 'Балл',
        grade: '85',
        date: '03.11.2026',
        semester: '7',
      ),
    ];
    const subjects = [
      BarsSubject(
        name: 'Моделирование систем управления',
        semester: '7',
        attestation: 'Экзамен',
        credits: '4',
        currentScore: '88',
        finalGrade: '5',
        controls: [],
      ),
    ];
    final stats = LessonGradesSummary.fromData(
      subject: first.subject,
      grades: grades,
      subjects: subjects,
    );
    expect(stats.average, 4.5);
    expect(stats.gradeCount, 2);
    expect(stats.currentScore, '88');
    expect(stats.finalGrade, '5');
  });

  test('missing grades never invent a class average', () {
    final stats = LessonGradesSummary.fromData(
      subject: first.subject,
      grades: const [],
      subjects: const [],
    );
    expect(stats.average, isNull);
    expect(stats.gradeCount, 0);
  });

  test('only the profile group unlocks details', () {
    expect(canOpenOwnLessonDetails(
      profileGroup: 'А-03-23', viewedGroup: 'A-03-23',
    ), isTrue);
    expect(canOpenOwnLessonDetails(
      profileGroup: 'А-03-23', viewedGroup: 'А-20-24',
    ), isFalse);
    expect(canOpenOwnLessonDetails(
      profileGroup: null, viewedGroup: 'А-03-23',
    ), isFalse);
  });

  testWidgets('one note field switches between private and group drafts',
      (tester) async {
    final api = _MockGroupLessonNotesApi();
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonDetailsSheet(
          group: 'А-03-23',
          lesson: first,
          scrollController: controller,
          notesApi: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('lesson-note-composer'));
    expect(input, findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Личный черновик');
    final toGroup = find.text('Для группы');
    await tester.ensureVisible(toGroup);
    await tester.tap(toGroup);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Опубликовать'), findsOneWidget);
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Групповой черновик');
    final toSelf = find.text('Для себя');
    await tester.ensureVisible(toSelf);
    await tester.tap(toSelf);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text,
        'Личный черновик');
    expect(find.text('Сохранить'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    api.dispose();
  });

  testWidgets('lesson card is tappable', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonCard(
          time: first.time,
          subject: first.subject,
          type: first.type,
          room: first.room,
          teacher: first.teacher,
          onTap: () => opened = true,
        ),
      ),
    ));
    await tester.tap(find.text(first.subject));
    expect(opened, isTrue);
  });
}

class _MockGroupLessonNotesApi extends GroupLessonNotesApi {
  @override
  Future<List<GroupLessonNote>> list(String group, ScheduleLesson lesson) async =>
      [];
}
