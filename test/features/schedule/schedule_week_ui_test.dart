import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/schedule/data/group_storage.dart';
import 'package:campusapp/features/schedule/data/lesson_kind.dart';
import 'package:campusapp/features/schedule/data/schedule_lesson.dart';
import 'package:campusapp/features/schedule/widgets/lesson_card.dart';
import 'package:campusapp/features/schedule/widgets/week_days_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lesson type determines green/yellow/red/gray colors', () {
    expect(lessonKind('Лекция'), LessonKind.lecture);
    expect(lessonKind('Практическое занятие'), LessonKind.practice);
    expect(lessonKind('Лабораторная работа'), LessonKind.laboratory);
    expect(lessonKind('Экзамен'), LessonKind.other);
    expect(lessonKindColor(LessonKind.lecture), const Color(0xFF34C759));
    expect(lessonKindColor(LessonKind.practice), const Color(0xFFFACC15));
    expect(lessonKindColor(LessonKind.laboratory), const Color(0xFFEF4444));
  });

  testWidgets('each lesson appears as a coloured dot on its day', (tester) async {
    final monday = DateTime(2026, 11, 2);
    const lessons = [
      ScheduleLesson(
        date: '02.11.2026',
        time: '09:20 - 10:55',
        subject: 'Математика',
        type: 'Лекция',
        room: 'С-409',
        teacher: '',
      ),
      ScheduleLesson(
        date: '02.11.2026',
        time: '11:10 - 12:45',
        subject: 'Информатика',
        type: 'Практика',
        room: 'С-405',
        teacher: '',
      ),
      ScheduleLesson(
        date: '02.11.2026',
        time: '13:15 - 14:50',
        subject: 'Физика',
        type: 'Лабораторная',
        room: 'С-401',
        teacher: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekDaysRow(
            selectedDate: monday,
            onDateSelected: (_) {},
            weekLessons: lessons,
          ),
        ),
      ),
    );

    for (var i = 0; i < 3; i++) {
      final dot = tester.widget<Container>(
        find.byKey(ValueKey('lesson-dot-2026-11-2-$i')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, lessonKindColor(LessonKind.values[i]));
    }
    expect(find.byKey(const ValueKey('lesson-dot-2026-11-3-0')),
        findsNothing);
  });

  testWidgets('lesson type is to the right of its time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonCard(
            time: '09:20 - 10:55',
            subject: 'Моделирование систем управления',
            type: 'Лекция',
            room: 'С-409',
            teacher: 'Васильев А.А.',
          ),
        ),
      ),
    );
    expect(find.text('Лекция'), findsOneWidget);
    expect(find.text('09:20 - 10:55'), findsOneWidget);
    expect(find.text('С-409'), findsOneWidget);
  });

  test('choosing a timetable group does not change BARS group', () async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    final storage = GroupStorage();
    expect(await storage.getScheduleGroup(), 'А-03-23');
    await storage.saveScheduleGroup('А-04-23');
    expect(await storage.getScheduleGroup(), 'А-04-23');
    expect(await storage.getGroup(), 'А-03-23');
  });
}
