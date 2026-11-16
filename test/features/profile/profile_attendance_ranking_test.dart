import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/profile/data/student_profile.dart';
import 'package:campusapp/features/profile/view/grade_ranking_screen.dart';
import 'package:campusapp/features/profile/view/profile_statistics_view.dart';
import 'package:campusapp/features/schedule/data/attendance_api.dart';

class _GradeApiStub extends AttendanceApi {
  _GradeApiStub(this.groupData, this.streamData);
  final GradeRanking groupData;
  final GradeRanking streamData;
  int queries = 0;
  int publishes = 0;
  int withdrawals = 0;
  String? lastSemester;
  List<GradeRankingSubject>? lastSubjects;

  @override
  Future<void> publishGradePoints(
    String semester, List<GradeRankingSubject> subjects,
  ) async {
    publishes++;
    lastSemester = semester;
    lastSubjects = subjects;
  }

  @override
  Future<void> withdrawGradePoints() async {
    withdrawals++;
  }

  @override
  Future<GradeRanking> gradeRanking({String scope = 'group'}) async {
    queries++;
    return scope == 'stream' ? streamData : groupData;
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

const _groupRanking = GradeRanking(
  scope: 'group', group: 'А-03-23',
  semester: '2026/2027 осенний', total: 13,
  participants: 6, myPlace: 2, myAverage: 78.5, published: true,
  entries: [
    GradeRankingEntry(
      place: 1, displayName: 'Антонов Дмитрий',
      group: 'А-03-23', averageScore: 89.0, subjectCount: 5, mine: false,
    ),
    GradeRankingEntry(
      place: 2, displayName: 'Петров Пётр',
      group: 'А-03-23', averageScore: 78.5, subjectCount: 5, mine: true,
    ),
  ],
);

const _streamRanking = GradeRanking(
  scope: 'stream', group: 'А-03-23',
  semester: '2026/2027 осенний', total: 65,
  participants: 22, myPlace: 5, myAverage: 78.5, published: true,
  entries: [],
);

Future<void> _pump(WidgetTester tester, _GradeApiStub api) async {
  tester.view.physicalSize = const Size(430, 1050);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileStatisticsView(
          profile: _profile,
          subjects: const [],
          rankingApi: api,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows scores, never saved attendance or explanatory banner',
      (tester) async {
    final api = _GradeApiStub(_groupRanking, _streamRanking);
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text('2 / 6'), findsOneWidget);
    expect(find.text('5 / 22'), findsOneWidget);
    expect(find.textContaining('Посещаемость'), findsNothing);
    expect(find.textContaining('Место в группе — по подтверждённой'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both score ranking cards open the leaderboard',
      (tester) async {
    final api = _GradeApiStub(_groupRanking, _streamRanking);
    addTearDown(api.dispose);
    await _pump(tester, api);
    await tester.tap(find.text('В группе'));
    await tester.pumpAndSettle();
    expect(find.text('Таблица мест'), findsOneWidget);
    expect(find.text('Антонов Дмитрий'), findsOneWidget);
    expect(find.text('Петров Пётр'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('На потоке'));
    await tester.pumpAndSettle();
    expect(find.text('Все группы с «А-»'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('do not invent places for unpublished academic scores',
      (tester) async {
    final api = _GradeApiStub(
      const GradeRanking(
        scope: 'group', group: 'А-03-23', semester: null,
        total: 13, participants: 0, myPlace: null,
        myAverage: null, published: false, entries: [],
      ),
      const GradeRanking(
        scope: 'stream', group: 'А-03-23', semester: null,
        total: 65, participants: 0, myPlace: null,
        myAverage: null, published: false, entries: [],
      ),
    );
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text('Участников: 0'), findsNWidgets(2));
    expect(find.text('13 / 13'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('publishing BARS scores requires an explicit confirmation',
      (tester) async {
    final api = _GradeApiStub(
      const GradeRanking(
        scope:'group', group:'А-03-23', semester:null,
        total:13, participants:0, myPlace:null,
        myAverage:null, published:false, entries:[],
      ), _streamRanking,
    );
    addTearDown(api.dispose);
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: GradeRankingScreen(
        scope:'group', api:api, subjects: const [
          BarsSubject(
            name:'ТАУ', semester:'2026/2027 осенний',
            attestation:'', credits:'', currentScore:'75,50',
            finalGrade:'', controls:[],
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('score-ranking-publish')));
    await tester.pumpAndSettle();
    expect(api.publishes, 0); // No automatic sharing
    expect(find.text('Опубликовать баллы?'), findsOneWidget);
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();
    expect(api.publishes, 1);
    expect(api.queries, greaterThanOrEqualTo(2));
    expect(api.lastSemester, '2026/2027 осенний');
    expect(api.lastSubjects!.single.points, 75.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant can withdraw their points from both rankings',
      (tester) async {
    final api = _GradeApiStub(_groupRanking, _streamRanking);
    addTearDown(api.dispose);
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: GradeRankingScreen(scope:'group', api:api, subjects: const []),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('score-ranking-delete')));
    await tester.pumpAndSettle();
    expect(api.withdrawals, 0);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(api.withdrawals, 1);
    expect(tester.takeException(), isNull);
  });

  test('read local BARS current score for the newest semester only', () {
    const subjects = [
      BarsSubject(
        name: 'Математика', semester: '2026/2027 осенний',
        attestation: '', credits: '', currentScore: '72,50',
        finalGrade: '', controls: [],
      ),
      BarsSubject(
        name: 'Физика', semester: '2026/2027 осенний',
        attestation: '', credits: '', currentScore: '87,50',
        finalGrade: '', controls: [],
      ),
      BarsSubject(
        name: 'История', semester: '2025/2026 осенний',
        attestation: '', credits: '', currentScore: '99',
        finalGrade: '', controls: [],
      ),
    ];
    final snapshot = GradeScoreSnapshot.parse(subjects)!;
    expect(snapshot.semester, '2026/2027 осенний');
    expect(snapshot.subjects.length, 2);
    expect(snapshot.average, 80);
  });
}
