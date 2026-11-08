import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/profile/data/student_grade.dart';
import 'package:campusapp/features/services/booking/data/classroom_booking_api.dart';
import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/schedule/data/lesson_grades_summary.dart';
import 'package:campusapp/features/schedule/data/lesson_group_access.dart';
import 'package:campusapp/features/schedule/data/own_lesson_note_preview_storage.dart';
import 'package:campusapp/features/schedule/widgets/lesson_note_preview.dart';
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

  testWidgets('lesson details opens booking for its own room and time',
      (tester) async {
    final when = DateTime.now().add(const Duration(days: 2));
    final dd = when.day.toString().padLeft(2, '0');
    final mm = when.month.toString().padLeft(2, '0');
    final lesson = ScheduleLesson(
      date: '$dd.$mm.${when.year}',
      time: '13:45 - 15:20',
      subject: 'Тестовая лекция',
      type: 'Лекция',
      room: 'С-409',
      teacher: 'Преподаватель',
    );
    final api = _MockGroupLessonNotesApi();
    final booking = _BookingApiSpy();
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LessonDetailsSheet(
        group: 'А-03-23',
        lesson: lesson,
        scrollController: controller,
        notesApi: api,
        bookingApi: booking,
      )),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('lesson-book-seat'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Бронирование аудиторий'), findsOneWidget);
    expect(find.text('С-409'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-room-change')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-fixed-lesson')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('booking-date')), findsNothing);
    expect(find.text('13:45 - 15:20'), findsOneWidget);
    expect(booking.lastSlot, '3');
    expect(booking.lastRoom, 'С-409');
    expect(ClassroomBookingApi.dateKey(booking.lastDate!),
        ClassroomBookingApi.dateKey(when));

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    booking.dispose();
    api.dispose();
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

  test('saved group preview is independent of private note and group', () async {
    final storage = OwnLessonNotePreviewStorage();
    await PrivateLessonNotesStorage().save(
      group: 'А-03-23', lesson: first, content: 'Личное ДЗ',
    );
    await storage.savePublished(
      group: 'А-03-23', lesson: first, content: 'Принести отчёт',
    );
    final firstRead = await OwnLessonNotePreviewStorage().load(
      group: 'А-03-23', lesson: first,
    );
    expect(firstRead.personal, 'Личное ДЗ');
    expect(firstRead.published, 'Принести отчёт');
    expect((await storage.load(group: 'А-04-23', lesson: first)).isEmpty, isTrue);
    expect((await storage.load(group: 'А-03-23', lesson: second)).isEmpty, isTrue);
    await storage.savePublished(
      group: 'А-03-23', lesson: first, content: '',
    );
    expect((await storage.load(group: 'А-03-23', lesson: first)).published,
        isEmpty);
    expect((await storage.load(group: 'А-03-23', lesson: first)).personal,
        'Личное ДЗ');
  });

  testWidgets('card preview appears after save and disappears after clearing',
      (tester) async {
    final storage = OwnLessonNotePreviewStorage();
    Future<void> show(int revision) => tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonCard(
          time: first.time,
          subject: first.subject,
          type: first.type,
          room: first.room,
          teacher: first.teacher,
          footer: LessonNotePreview(
            group: 'А-03-23',
            lesson: first,
            revision: revision,
          ),
        ),
      ),
    ));
    await show(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-note-preview')), findsNothing);

    await PrivateLessonNotesStorage().save(
      group: 'А-03-23', lesson: first, content: 'Повторить тему',
    );
    await show(1);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-note-preview')), findsOneWidget);
    expect(find.textContaining('Повторить тему', findRichText: true),
        findsOneWidget);

    await storage.savePublished(
      group: 'А-03-23', lesson: first, content: 'Конспект группе',
    );
    await show(2);
    await tester.pumpAndSettle();
    expect(find.textContaining('Конспект группе', findRichText: true),
        findsOneWidget);

    await PrivateLessonNotesStorage().save(
      group: 'А-03-23', lesson: first, content: '',
    );
    await storage.savePublished(
      group: 'А-03-23', lesson: first, content: '',
    );
    await show(3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-note-preview')), findsNothing);
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

class _BookingApiSpy extends ClassroomBookingApi {
  DateTime? lastDate;
  String? lastSlot;
  String? lastRoom;

  @override
  Future<ClassroomAvailability> load({
    required DateTime date,
    required String slot,
    String room = 'М-307',
    bool trySession = true,
  }) async {
    lastDate = date;
    lastSlot = slot;
    lastRoom = room;
    return ClassroomAvailability(
      room: room,
      date: ClassroomBookingApi.dateKey(date),
      slot: slot,
      occupied: const <ClassroomSeat>{},
      mine: null,
      slots: classroomDemoSlots,
      testMode: true,
    );
  }
}
