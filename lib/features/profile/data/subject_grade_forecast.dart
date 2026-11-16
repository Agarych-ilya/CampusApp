import 'dart:math' as math;
import 'bars_subject.dart';

class GradeForecastTarget {
  const GradeForecastTarget({
    required this.grade,required this.threshold,
    required this.status,this.requiredRemainingAverage,
  });
  final int grade;
  final double threshold;
  final String status;
  final double? requiredRemainingAverage;
}

/// Adapted from Arut4242/spark-mpei GradeForecastHelper.kt (MIT).
/// Estimated thresholds only; actual BARS grading is authoritative.
class SubjectGradeForecast {
  const SubjectGradeForecast({
    required this.earnedWeightedScore,
    required this.gradedAverage,
    required this.totalWeight,
    required this.gradedWeight,
    required this.gradedCount,
    required this.remainingCount,
    required this.excludedCount,
    required this.targets,
  });
  final double earnedWeightedScore;
  final double? gradedAverage;
  final double totalWeight,gradedWeight;
  final int gradedCount,remainingCount,excludedCount;
  final List<GradeForecastTarget> targets;

  static const thresholds=<int,double>{5:4.2,4:3.5,3:2.5};
  static double floorTenths(double x) => (x*10+1e-7).floorToDouble()/10;

  static double? controlWeight(String raw) {
    final text=raw.replaceAll(RegExp(r'\s'),'')
        .replaceAll('%','').replaceAll(',','.');
    if(!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) return null;
    final x=double.tryParse(text);
    return x!=null && x.isFinite && x>0 && x<=100 ? x : null;
  }

  /// Recognize numeric grades, dated grades, written retakes and short labels.
  static double? controlGrade(String raw) {
    final text=raw.toLowerCase().trim();
    if(text.isEmpty || text=='—' || text=='-') return null;
    final retake=RegExp(r'^2\s*(?:/|→|->)\s*([3-5])(?:\D|$)')
        .firstMatch(text);
    if(retake!=null) return (2+int.parse(retake.group(1)!))/2;
    final match=RegExp(r'^([2-5])(?:[.,](\d+))?(?=\D|$)')
        .firstMatch(text);
    if(match!=null) {
      final x=double.tryParse(match.group(1)!+
          (match.group(2)==null ? '' : '.'+match.group(2)!));
      if(x!=null && x>=2 && x<=5) return x;
    }
    if(text.contains('незач')||text=='неуд') return 2;
    if(text.contains('зач')||text=='отл') return 5;
    if(text=='хор') return 4;
    if(text=='уд'||text=='удовл') return 3;
    return null;
  }

  /// Simulation index corresponds to original BARS control order.
  /// If a 2 is retaken, the effective grade is (2 + newGrade) / 2.
  static SubjectGradeForecast? calculate(
    BarsSubject subject, {
    Map<int, int> simulations = const {},
  }) {
    double total=0,closed=0,earned=0;
    var graded=0,remaining=0,excluded=0;
    for(var i=0;i<subject.controls.length;i++) {
      final control=subject.controls[i];
      final weight=controlWeight(control.weight);
      if(weight==null){excluded++;continue;}
      total+=weight;
      final original=controlGrade(control.grade);
      final simulated=simulations[i];
      final effective=simulated==null ? original
          : original==2 && simulated>2
              ? (2+simulated)/2 : simulated.toDouble();
      if(effective==null){remaining++;continue;}
      graded++;closed+=weight;earned+=effective*weight;
    }
    if(total<=0) return null;
    final open=total-closed;
    final score=earned/total;
    final lower=(earned+2*open)/total;
    final upper=(earned+5*open)/total;
    final targets=<GradeForecastTarget>[];
    for(final threshold in thresholds.entries) {
      if(floorTenths(lower)>=threshold.value){
        targets.add(GradeForecastTarget(
          grade:threshold.key,threshold:threshold.value,
          status:'guaranteed',
        ));
      } else if(floorTenths(upper)<threshold.value){
        targets.add(GradeForecastTarget(
          grade:threshold.key,threshold:threshold.value,
          status:'impossible',
        ));
      } else {
        targets.add(GradeForecastTarget(
          grade:threshold.key,threshold:threshold.value,
          status:'achievable',
          requiredRemainingAverage:((threshold.value*total-earned)/
              math.max(open,0.000001)).clamp(2.0,5.0).toDouble(),
        ));
      }
    }
    return SubjectGradeForecast(
      earnedWeightedScore:score,
      gradedAverage:closed>0?earned/closed:null,
      totalWeight:total,gradedWeight:closed,
      gradedCount:graded,remainingCount:remaining,
      excludedCount:excluded,targets:targets,
    );
  }
}
