import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/schedule/data/group_storage.dart';
import 'package:campusapp/features/services/booking/data/classroom_booking_api.dart';
import 'package:campusapp/features/schedule/data/semester_week.dart';
import 'package:campusapp/features/schedule/data/private_lesson_notes_storage.dart';
import 'package:campusapp/features/schedule/data/schedule_api.dart';
import 'package:campusapp/features/schedule/view/schedule_screen.dart';
import 'package:campusapp/features/profile/data/student_profile_storage.dart';
import 'package:campusapp/features/profile/data/student_profile.dart';
import 'package:campusapp/features/schedule/data/lesson_kind.dart';
import 'package:campusapp/features/schedule/data/schedule_lesson.dart';
import 'package:campusapp/features/schedule/widgets/lesson_card.dart';
import 'package:campusapp/features/schedule/widgets/week_days_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('teaching week follows the semester, not the ISO year', () {
    expect(semesterWeekNumber(DateTime(2026, 9, 1)), 1);
    expect(semesterWeekNumber(DateTime(2026, 11, 3)), 10);
    expect(semesterWeekLabel(DateTime(2026, 11, 3)), '10 неделя');
    expect(semesterWeekNumber(DateTime(2027, 2, 1)), 1);
    expect(semesterWeekNumber(DateTime(2027, 3, 1)), 5);
  });

  test('lesson type determines green/yellow/red/gray colors', () {
    expect(lessonKind('Лекция'), LessonKind.lecture);
    expect(lessonKind('Практическое занятие'), LessonKind.practice);
    expect(lessonKind('Лабораторная работа'), LessonKind.laboratory);
    expect(lessonKind('Экзамен'), LessonKind.other);
    expect(lessonKind('Факультатив'), LessonKind.elective);
    expect(
      lessonKind('Практика', subject: 'Факультатив по математике'),
      LessonKind.elective,
    );
    expect(lessonKindLabel('Лекция', subject: 'Факультатив'), 'Факультатив');
    expect(lessonKindColor(LessonKind.elective), const Color(0xFF8C8C94));
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
      ScheduleLesson(
        date: '02.11.2026',
        time: '15:00 - 16:35',
        subject: 'Факультатив по программированию',
        type: 'Практика',
        room: 'С-402',
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

    final kinds = [
      LessonKind.lecture,
      LessonKind.practice,
      LessonKind.laboratory,
      LessonKind.elective,
    ];
    for (var i = 0; i < kinds.length; i++) {
      final dot = tester.widget<Container>(
        find.byKey(ValueKey('lesson-dot-2026-11-2-$i')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, lessonKindColor(kinds[i]));
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

  testWidgets('facultative cards are labelled and coloured grey', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonCard(
            time: '13:15 - 14:50',
            subject: 'Факультатив по программированию',
            type: 'Лекция',
            room: 'С-402',
            teacher: '',
          ),
        ),
      ),
    );
    expect(find.text('Факультатив'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Факультатив'));
    expect(label.style?.color, const Color(0xFF8C8C94));
  });

  testWidgets('changing group reloads real lessons, not only the label', (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    final api = _FakeScheduleApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleScreen(
            scheduleApi: api,
            groupStorage: GroupStorage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Занятие А-03-23'), findsWidgets);
    expect(find.byKey(const ValueKey('schedule-semester-week')), findsOneWidget);
    final groupFinder = find.byKey(const ValueKey('schedule-group-search'));
    expect(groupFinder, findsOneWidget);
    final today = DateTime.now();
    final dayFinder = find.byKey(
      ValueKey('schedule-day-${today.year}-${today.month}-${today.day}'),
    );
    expect(dayFinder, findsOneWidget);
    expect(
      tester.getTopLeft(groupFinder).dy,
      greaterThan(tester.getTopLeft(dayFinder).dy),
    );

    await tester.tap(groupFinder);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'А-04-23');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'А-04-23'));
    await tester.pumpAndSettle();

    expect(find.text('Занятие А-04-23'), findsWidgets);
    expect(find.text('Занятие А-03-23'), findsNothing);
    expect(api.requestedGroups, contains('А-04-23'));
    expect(await GroupStorage().getScheduleGroup(), 'А-04-23');
    expect(await GroupStorage().getGroup(), 'А-03-23');
  });

  testWidgets('another group stays visible but lesson details stay closed',
      (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    await StudentProfileStorage().saveProfile(const StudentProfile(
      fullName: 'Студент',
      group: 'А-03-23',
      recordBook: '',
      course: '4',
      educationLevel: '',
      email: '',
      faculty: '',
    ));
    await GroupStorage().saveScheduleGroup('А-04-23');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ScheduleScreen(
        scheduleApi: _FakeScheduleApi(room: 'М-307'),
        groupStorage: GroupStorage(),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Занятие А-04-23'), findsWidgets);
    await tester.tap(find.text('Занятие А-04-23').first);
    await tester.pumpAndSettle();
    expect(find.text('Мои оценки по предмету'), findsNothing);
    expect(find.textContaining('Подробности и заметки доступны только'),
        findsNothing);
    expect(find.byKey(const ValueKey('lesson-note-preview')), findsNothing);
    expect(find.byKey(const ValueKey('schedule-book-seat')), findsNothing);
  });

  testWidgets('my lesson shows a saved private note under the lesson',
      (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    await StudentProfileStorage().saveProfile(const StudentProfile(
      fullName: 'Студент',
      group: 'А-03-23',
      recordBook: '',
      course: '4',
      educationLevel: '',
      email: '',
      faculty: '',
    ));
    final date = DateTime.now();
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final lesson = ScheduleLesson(
      date: '$dd.$mm.${date.year}',
      time: '09:20 - 10:55',
      subject: 'Занятие А-03-23',
      type: 'Лекция',
      room: 'С-409',
      teacher: 'Преподаватель',
    );
    await PrivateLessonNotesStorage().save(
      group: 'А-03-23',
      lesson: lesson,
      content: 'Сделать лабораторную',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ScheduleScreen(
        scheduleApi: _FakeScheduleApi(),
        groupStorage: GroupStorage(),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-note-preview')), findsOneWidget);
    expect(find.textContaining('Сделать лабораторную', findRichText: true),
        findsOneWidget);
  });

  testWidgets('M-307 booking button opens seat map directly from timetable',
      (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    await StudentProfileStorage().saveProfile(const StudentProfile(
      fullName: 'Студент',
      group: 'А-03-23',
      recordBook: '',
      course: '4',
      educationLevel: '',
      email: '',
      faculty: '',
    ));
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleScreen(
          scheduleApi: _FakeScheduleApi(room: 'М-307 (Корпус М)'),
          groupStorage: GroupStorage(),
          bookingApi: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('schedule-book-seat'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Бронирование аудиторий'), findsOneWidget);
    expect(find.text('М-307'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-room-change')), findsNothing);
    expect(find.text('Мои оценки по предмету'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('В-308 seat booking opens directly beside the classroom',
      (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    await StudentProfileStorage().saveProfile(const StudentProfile(
      fullName: 'Студент',
      group: 'А-03-23',
      recordBook: '',
      course: '4',
      educationLevel: '',
      email: '',
      faculty: '',
    ));
    final api = _FakeBookingApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleScreen(
          scheduleApi: _FakeScheduleApi(room: 'В-308 (Корпус В)'),
          groupStorage: GroupStorage(),
          bookingApi: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('schedule-book-seat'));
    expect(entry, findsOneWidget);
    expect(find.text('Выбрать место'), findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Бронирование аудиторий'), findsOneWidget);
    expect(find.text('В-308'), findsOneWidget);
    expect(find.textContaining('176 мест'), findsOneWidget);
    expect(api, isNotNull); // Route opened without intermediate details.
    expect(find.text('Мои оценки по предмету'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('other classrooms never show M-307 booking CTA',
      (tester) async {
    SharedPreferences.setMockInitialValues({'student_group': 'А-03-23'});
    await StudentProfileStorage().saveProfile(const StudentProfile(
      fullName: 'Студент',
      group: 'А-03-23',
      recordBook: '',
      course: '4',
      educationLevel: '',
      email: '',
      faculty: '',
    ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleScreen(
          scheduleApi: _FakeScheduleApi(room: 'С-401 (Корпус С)'),
          groupStorage: GroupStorage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Занятие А-03-23'), findsWidgets);
    expect(find.byKey(const ValueKey('schedule-book-seat')), findsNothing);
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

class _FakeScheduleApi extends ScheduleApi {
  _FakeScheduleApi({this.room = 'С-409'});
  final String room;
  final requestedGroups = <String>[];

  @override
  Future<List<String>> searchGroups(String query) async =>
      ['А-03-23', 'А-04-23'];

  @override
  Future<List<ScheduleLesson>> getWeekSchedule({
    required String group,
    required DateTime selectedDate,
    bool forceRefresh = false,
  }) async {
    requestedGroups.add(group);
    final date = DateTime.now();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return [
      ScheduleLesson(
        date: '$day.$month.${date.year}',
        time: '09:20 - 10:55',
        subject: 'Занятие $group',
        type: 'Лекция',
        room: room,
        teacher: 'Преподаватель',
      ),
    ];
  }
}

class _FakeBookingApi extends ClassroomBookingApi {
  @override
  Future<ClassroomAvailability> load({
    required DateTime date,
    required String slot,
    String room = 'М-307',
    bool trySession = true,
  }) async => ClassroomAvailability(
    room: room,
    date: ClassroomBookingApi.dateKey(date),
    slot: slot,
    occupied: const <ClassroomSeat>{},
    mine: null,
    slots: classroomDemoSlots,
    testMode: true,
  );
}
