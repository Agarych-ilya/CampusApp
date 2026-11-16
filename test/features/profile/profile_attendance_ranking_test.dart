import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/features/profile/data/student_profile.dart';
import 'package:campusapp/features/profile/view/profile_statistics_view.dart';
import 'package:campusapp/features/schedule/data/attendance_api.dart';

class _RankingApiStub extends AttendanceApi {
  _RankingApiStub(this.value);
  final AttendanceRanking value;
  int calls = 0;

  @override
  Future<AttendanceRanking> ranking() async {
    calls++;
    return value;
  }
}

const _profile = StudentProfile(
  fullName: 'Петров Пётр Сергеевич',
  group: 'А-03-23',
  recordBook: '',
  course: '4',
  educationLevel: '',
  email: '',
  faculty: '',
);

Future<void> _pump(
  WidgetTester tester, AttendanceApi api, {int revision = 0},
) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileStatisticsView(
          profile: _profile,
          subjects: const [],
          rankingApi: api,
          rankingRevision: revision,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows own attendance rank only after roster and review',
      (tester) async {
    final api = _RankingApiStub(const AttendanceRanking(
      group: 'А-03-23', imported: true, total: 13,
      rank: 2, attended: 4, reviewedLessons: 5,
    ));
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text('2 / 13'), findsOneWidget);
    expect(find.text('Посещаемость'), findsOneWidget);
    expect(find.text('Нет данных'), findsOneWidget); // Cohort is not known.
    expect(api.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('imported roster is shown without inventing an academic rank',
      (tester) async {
    final api = _RankingApiStub(const AttendanceRanking(
      group: 'А-03-23', imported: true, total: 13,
      rank: null, attended: 0, reviewedLessons: 0,
    ));
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text('— / 13'), findsOneWidget);
    expect(find.text('Нет отметок'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not invent a rank before roster import',
      (tester) async {
    final api = _RankingApiStub(const AttendanceRanking(
      group: 'А-03-23', imported: false, total: 0,
      rank: null, attended: 0, reviewedLessons: 0,
    ));
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text('Нет группы'), findsOneWidget);
    expect(find.text('— / 0'), findsNothing);
  });
}
