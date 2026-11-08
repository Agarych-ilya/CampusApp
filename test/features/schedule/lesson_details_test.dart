import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/profile/data/student_grade.dart';
import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/schedule/data/lesson_grades_summary.dart';
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
