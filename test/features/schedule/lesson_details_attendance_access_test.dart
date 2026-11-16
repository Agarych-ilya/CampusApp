import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/schedule/data/attendance_api.dart';
import 'package:campusapp/features/schedule/data/schedule_lesson.dart';
import 'package:campusapp/features/schedule/view/lesson_details_sheet.dart';

const _lesson = ScheduleLesson(
  date: '16.11.2026',
  time: '11:10 - 12:45',
  subject: 'Системы управления базами данных',
  type: 'Лекция',
  room: 'М-307',
  teacher: 'Преподаватель',
);

class _AttendanceRoleStub extends AttendanceApi {
  _AttendanceRoleStub(this.identity, {this.throwError = false});
  final AttendanceIdentity identity;
  final bool throwError;

  @override
  Future<AttendanceIdentity> session() async {
    if (throwError) throw StateError('session expired');
    return identity;
  }
}

AttendanceIdentity _identity({
  required bool starosta,
  String group = 'А-03-23',
  bool authenticated = true,
}) => AttendanceIdentity(
  authenticated: authenticated,
  isStarosta: starosta,
  registered: true,
  group: group,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showSheet(WidgetTester tester, AttendanceApi api) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonDetailsSheet(
          group: 'А-03-23',
          lesson: _lesson,
          scrollController: scrollController,
          attendanceApi: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('regular student does not see journal action', (tester) async {
    final api = _AttendanceRoleStub(_identity(starosta: false));
    addTearDown(api.dispose);
    await showSheet(tester, api);
    expect(find.byKey(const ValueKey('open-attendance-journal')),
        findsNothing);
    expect(find.text('Мои оценки по предмету'), findsOneWidget);
  });

  testWidgets('verified starosta sees journal action', (tester) async {
    final api = _AttendanceRoleStub(_identity(starosta: true));
    addTearDown(api.dispose);
    await showSheet(tester, api);
    expect(find.byKey(const ValueKey('open-attendance-journal')),
        findsOneWidget);
  });

  testWidgets('starosta of another group cannot see journal action',
      (tester) async {
    final api = _AttendanceRoleStub(
      _identity(starosta: true, group: 'А-04-23'),
    );
    addTearDown(api.dispose);
    await showSheet(tester, api);
    expect(find.byKey(const ValueKey('open-attendance-journal')),
        findsNothing);
  });

  testWidgets('expired session hides journal action', (tester) async {
    final api = _AttendanceRoleStub(_identity(starosta: true),
        throwError: true);
    addTearDown(api.dispose);
    await showSheet(tester, api);
    expect(find.byKey(const ValueKey('open-attendance-journal')),
        findsNothing);
  });
}
