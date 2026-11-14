import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/schedule/data/attendance_api.dart';
import 'package:campusapp/features/schedule/data/schedule_lesson.dart';
import 'package:campusapp/features/schedule/view/attendance_lesson_screen.dart';

const lesson = ScheduleLesson(
  date: '14.11.2026',
  time: '10:00–11:30',
  subject: 'Теория управления',
  type: 'Лекция',
  room: 'В-308',
  teacher: 'Преподаватель',
);

class _AttendanceFake extends AttendanceApi {
  _AttendanceFake({required this.starosta});
  final bool starosta;
  bool failFirstSession = false;
  String firstSessionError =
      'Не удалось связаться с БАРС для проверки сессии';
  int sessionCalls = 0;
  bool opened = false;
  bool pending = false;
  int checkedIn = 0;
  int decided = 0;
  int closed = 0;
  Set<String> savedAbsences = {};
  final firstStudentKey = List.filled(64, 'a').join();
  final secondStudentKey = List.filled(64, 'b').join();

  @override
  Future<AttendanceIdentity> session() async {
    sessionCalls++;
    if (failFirstSession && sessionCalls == 1) {
      throw Exception(firstSessionError);
    }
    return AttendanceIdentity(
      authenticated: true,
      isStarosta: starosta,
      registered: true,
      group: 'А-03-23',
      displayName: starosta ? 'Староста' : 'Студент',
    );
  }

  @override
  Future<AttendanceRoster> roster() async => AttendanceRoster(
    group: 'А-03-23',
    imported: true,
    students: [
      AttendanceStudent(
        ownerKey: firstStudentKey,
        displayName: 'Иванов Иван',
        status: 'unmarked',
      ),
      AttendanceStudent(
        ownerKey: secondStudentKey,
        displayName: 'Петров Пётр',
        status: 'unmarked',
      ),
    ],
  );

  @override
  Future<void> saveAbsences(
    int lessonId, List<String> rosterKeys, Set<String> absentKeys,
  ) async {
    expect(lessonId, 7);
    expect(rosterKeys.toSet(), {firstStudentKey, secondStudentKey});
    savedAbsences = Set.of(absentKeys);
    closed++;
  }

  @override
  Future<List<AttendanceLesson>> lessons(DateTime date) async {
    expect(date.year, 2026);
    if (!opened) return [];
    return const [
      AttendanceLesson(id: 7, date: '2026-11-14',
        time: '10:00–11:30', subject: 'Теория управления',
        state: closed > 0 ? 'closed' : 'open'),
    ];
  }

  @override
  Future<int> open(ScheduleLesson value) async {
    expect(value.subject, lesson.subject);
    opened = true;
    return 7;
  }

  @override
  Future<AttendanceDetail> detail(int id) async {
    expect(id, 7);
    return AttendanceDetail(
      lesson: const AttendanceLesson(
        id: 7, date: '2026-11-14', time: '10:00–11:30',
        subject: 'Теория управления',
        state: closed > 0 ? 'closed' : 'open',
      ),
      myStatus: starosta ? 'unmarked' : (pending ? 'pending' : 'unmarked'),
      students: starosta ? [
        AttendanceStudent(
          ownerKey: firstStudentKey, displayName: 'Иванов Иван',
          status: closed > 0 ? 'present' : 'unmarked',
        ),
        AttendanceStudent(
          ownerKey: secondStudentKey, displayName: 'Петров Пётр',
          status: savedAbsences.contains(secondStudentKey)
              ? 'absent' : 'unmarked',
        ),
      ] : [],
    );
  }

  @override
  Future<void> checkIn(int id) async {
    checkedIn++;
    pending = true;
  }

  @override
  Future<void> decide(int id, AttendanceStudent person, String status) async {
    expect(status, 'present');
    expect(person.ownerKey, List.filled(64, 'a').join());
    decided++;
  }
}

void main() {
  test('BARS attendance roster parser rejects invalid student keys', () {
    expect(() => AttendanceStudent.fromJson({
      'ownerKey': 'not-a-server-key',
      'displayName': 'Подставной',
      'status': 'present',
    }), throwsFormatException);
  });

  testWidgets('BARS connectivity error has retry and recovers without login',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _AttendanceFake(starosta: false)
      ..opened = true
      ..failFirstSession = true;
    await tester.pumpWidget(MaterialApp(home: AttendanceLessonScreen(
      group: 'А-03-23', lesson: lesson, api: api,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось связаться с БАРС'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attendance-retry-session')));
    await tester.pumpAndSettle();
    expect(api.sessionCalls, 2);
    expect(find.text('Я присутствую'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired BARS session offers re-login without wiping profile',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _AttendanceFake(starosta: false)
      ..opened = true
      ..failFirstSession = true
      ..firstSessionError =
          'БАРС не подтвердил сессию (список студентов, HTTP 302)';
    await tester.pumpWidget(MaterialApp(home: AttendanceLessonScreen(
      group: 'А-03-23', lesson: lesson, api: api,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('HTTP 302'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-reconnect-bars')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-retry-session')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student check-in remains pending until starosta approval',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _AttendanceFake(starosta: false)..opened = true;
    await tester.pumpWidget(MaterialApp(home: AttendanceLessonScreen(
      group: 'А-03-23', lesson: lesson, api: api,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Я присутствую'), findsOneWidget);
    await tester.tap(find.text('Я присутствую'));
    await tester.pumpAndSettle();
    expect(api.checkedIn, 1);
    expect(find.textContaining('Ожидает проверки'), findsOneWidget);
    expect(find.text('Пропуск'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starosta marks only absentees from imported group roster',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _AttendanceFake(starosta: true);
    await tester.pumpWidget(MaterialApp(home: AttendanceLessonScreen(
      group: 'А-03-23', lesson: lesson, api: api,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Загружено студентов: 2'), findsOneWidget);
    expect(find.text('Добавить себя'), findsNothing);
    await tester.tap(find.text('Открыть журнал пары'));
    await tester.pumpAndSettle();
    expect(find.text('Выбери отсутствующих'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Петров Пётр'), findsOneWidget);

    await tester.tap(find.byKey(
      ValueKey('attendance-absent-${api.secondStudentKey}'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Отсутствуют: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-reviewed-absences')));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить посещаемость?'), findsOneWidget);
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();

    expect(api.closed, 1);
    expect(api.savedAbsences, {api.secondStudentKey});
    expect(find.text('Итоговые отметки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
