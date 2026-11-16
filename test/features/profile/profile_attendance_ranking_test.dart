import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/profile/data/bars_control.dart';
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
            finalGrade:'', controls:[
              BarsControl(title:'Практическая',weight:'25',deadline:'',grade:'5'),
            ],
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
    expect(api.lastSemester, 'Все семестры');
    expect(api.lastSubjects!.single.points, 5);
    expect(api.lastSubjects!.single.weight, 25);
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

  test('weighted mean uses every graded control with its weight, not currentScore',
    () {
    const subjects = [
      BarsSubject(
        name:'Математика', semester:'2026/2027 осенний',
        attestation:'', credits:'', currentScore:'2.65',
        finalGrade:'5', controls:[
          BarsControl(title:'Работа 1',weight:'30',deadline:'',grade:'5'),
          BarsControl(title:'Работа 2',weight:'70%',deadline:'',grade:'4 (16.11.2026)'),
        ],
      ),
      BarsSubject(
        name:'История', semester:'2025/2026 осенний',
        attestation:'', credits:'', currentScore:'99',
        finalGrade:'2', controls:[
          BarsControl(title:'Работа 3',weight:'20',deadline:'',grade:'3'),
          BarsControl(title:'Без веса',weight:'',deadline:'',grade:'5'),
          BarsControl(title:'Не оценено',weight:'15',deadline:'',grade:''),
        ],
      ),
    ];
    final snapshot = GradeScoreSnapshot.parse(subjects)!;
    expect(snapshot.semester,'Все семестры');
    expect(snapshot.subjects.length,3);
    expect(snapshot.missingWeights,1);
    expect(snapshot.weightedSum,490); // 5*30 + 4*70 + 3*20
    expect(snapshot.totalWeight,120);
    expect(snapshot.average,closeTo(490 / 120,1e-10));
    expect(snapshot.subjects.first.points,5);
    expect(snapshot.subjects.first.weight,30);
    expect(snapshot.subjects.last.weight,20);
    // Old 2.65 from currentScore must never be used as the ranking value.
    expect(snapshot.average, isNot(2.65));
  });

  test('published weighted scores use the same effective retake grade', () {
    const subjects = [
      BarsSubject(
        name:'ТАУ',semester:'2026/2027 осенний',
        attestation:'',credits:'',currentScore:'2.65',
        finalGrade:'',
        controls: [
          BarsControl(title:'Первый КМ',weight:'30',deadline:'',grade:'2/5'),
          BarsControl(title:'Второй КМ',weight:'70',deadline:'',grade:'4'),
        ],
      ),
    ];
    final snapshot=GradeScoreSnapshot.parse(subjects)!;
    expect(snapshot.subjects.length,2);
    expect(snapshot.subjects.first.points,3.5);
    expect(snapshot.average,closeTo(3.85,1e-10));
  });

  test('unweighted BARS controls do not fabricate a 0 grade', () {
    const subjects = [
      BarsSubject(
        name:'ТАУ',semester:'2026/2027 осенний',
        attestation:'',credits:'',currentScore:'2.65',
        finalGrade:'5',
        controls:[
          BarsControl(title:'Письменная',weight:'?',deadline:'',grade:'5'),
        ],
      ),
    ];
    expect(GradeScoreSnapshot.parse(subjects),isNull);
  });
}
