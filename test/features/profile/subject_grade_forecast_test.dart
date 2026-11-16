import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/profile/data/bars_control.dart';
import 'package:campusapp/features/profile/data/bars_subject.dart';
import 'package:campusapp/features/profile/data/subject_grade_forecast.dart';

BarsSubject subject(List<BarsControl> cs) => BarsSubject(
  name:'ТАУ',semester:'2026/2027',attestation:'Экзамен',
  credits:'',currentScore:'2.65',finalGrade:'',controls:cs,
);
BarsControl km(String w,String g) => BarsControl(
  title:'КМ',weight:w,deadline:'',grade:g,
);

void main(){
  test('actual weighted grades, not currentScore or plain mean',(){
    final f=SubjectGradeForecast.calculate(
      subject([km('30%', '5'),km('70','4 (10.11.2026)')]))!;
    expect(f.gradedAverage,closeTo(4.3,1e-9));
    expect(f.earnedWeightedScore,closeTo(4.3,1e-9));
    expect(f.remainingCount,0);
    expect(f.targets.first.status,'guaranteed');
  });
  test('open KM affects attainable score but not mean over graded ones',(){
    final f=SubjectGradeForecast.calculate(
      subject([km('40','5'),km('60','')]))!;
    expect(f.gradedAverage,5);
    expect(f.earnedWeightedScore,2);
    expect(f.targets.first.status,'achievable');
    expect(f.targets.first.requiredRemainingAverage,
      closeTo(3.666666666,1e-6));
  });
  test('Spark retake from 2 -> 5 counts as 3.5 exactly once',(){
    final simulated=SubjectGradeForecast.calculate(
      subject([km('100','2')]),simulations:{0:5})!;
    expect(simulated.gradedAverage,3.5);
    final registered=SubjectGradeForecast.calculate(
      subject([km('100','2/5')]))!;
    expect(registered.gradedAverage,3.5);
  });
  test('unknown weight is excluded, not assumed to be zero',(){
    final f=SubjectGradeForecast.calculate(
      subject([km('?','5'),km('40','')]))!;
    expect(f.excludedCount,1);
    expect(f.gradedAverage,isNull);
    expect(SubjectGradeForecast.calculate(subject([km('','5')])),isNull);
  });
  test('tenths truncated down',(){
    expect(SubjectGradeForecast.floorTenths(4.29),4.2);
    expect(SubjectGradeForecast.floorTenths(4.19),4.1);
  });
}
