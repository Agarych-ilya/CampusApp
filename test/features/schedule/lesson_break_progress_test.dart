import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/schedule/data/lesson_break_progress.dart';

void main(){
  final date=DateTime(2026,11,16);
  DateTime utc(int hour,int minute)=>
      DateTime.utc(2026,11,16,hour-3,minute);

  test('45-minute first half',(){
    final info=LessonBreakProgress.calculate(
      lessonDate:date,time:'08:30–10:05',nowUtc:utc(9,0))!;
    expect(info.stage,LessonStage.firstHalf);
    expect(info.untilBreakMinutes,15);
    expect(info.remainingMinutes,65);
  });

  test('five minute break starts at 09:15',(){
    final info=LessonBreakProgress.calculate(
      lessonDate:date,time:'08:30–10:05',nowUtc:utc(9,17))!;
    expect(info.stage,LessonStage.breakTime);
    expect(info.breakRemainingMinutes,3);
    expect(info.progress,closeTo(47/95,1e-10));
  });

  test('second half, end of lesson and invalid time',(){
    final info=LessonBreakProgress.calculate(
      lessonDate:date,time:'08:30–10:05',nowUtc:utc(9,30))!;
    expect(info.stage,LessonStage.secondHalf);
    expect(info.remainingMinutes,35);
    expect(LessonBreakProgress.calculate(
      lessonDate:date,time:'08:30–10:05',nowUtc:utc(10,5)),isNull);
    expect(LessonBreakProgress.parseRange('неверно'),isNull);
  });
}
