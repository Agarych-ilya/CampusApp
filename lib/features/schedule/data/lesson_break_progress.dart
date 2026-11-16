enum LessonStage { firstHalf, breakTime, secondHalf }

/// Spark MPEI: a 95-minute lesson has two 45-minute halves and a 5-minute break.
class LessonBreakProgress {
  const LessonBreakProgress({
    required this.stage, required this.progress,
    required this.remainingMinutes, required this.untilBreakMinutes,
    required this.breakRemainingMinutes,
  });

  final LessonStage stage;
  final double progress;
  final int remainingMinutes, untilBreakMinutes, breakRemainingMinutes;

  static ({int start, int end})? parseRange(String time) {
    final parts=RegExp(r'(\d{1,2}):(\d{2})').allMatches(time).toList();
    if(parts.length<2) return null;
    int? value(RegExpMatch m) {
      final h=int.tryParse(m.group(1)!);
      final min=int.tryParse(m.group(2)!);
      if(h==null||min==null||h>23||min>59) return null;
      return h*60+min;
    }
    final a=value(parts[0]),b=value(parts[1]);
    if(a==null||b==null||b<=a) return null;
    return (start:a,end:b);
  }

  static LessonBreakProgress? calculate({
    required DateTime lessonDate, required String time, DateTime? nowUtc,
  }) {
    final span=parseRange(time);
    if(span==null) return null;
    // Moscow is UTC+3 all year: ignore the Android emulator local timezone.
    final now=(nowUtc??DateTime.now().toUtc()).toUtc()
        .add(const Duration(hours:3));
    if(lessonDate.year!=now.year||lessonDate.month!=now.month||
        lessonDate.day!=now.day) return null;
    final minute=now.hour*60+now.minute;
    if(minute<span.start||minute>=span.end) return null;

    final total=span.end-span.start;
    final breakDuration=total>=15 ? 5 : 0;
    final first=(total-breakDuration)~/2;
    final breakStart=span.start+first;
    final breakEnd=breakStart+breakDuration;
    final stage=breakDuration==0||minute<breakStart
        ? LessonStage.firstHalf
        : minute<breakEnd ? LessonStage.breakTime : LessonStage.secondHalf;

    return LessonBreakProgress(
      stage:stage,
      progress:((minute-span.start)/total).clamp(0.0,1.0).toDouble(),
      remainingMinutes:span.end-minute,
      untilBreakMinutes:(breakStart-minute).clamp(0,total).toInt(),
      breakRemainingMinutes:stage==LessonStage.breakTime
          ? breakEnd-minute : 0,
    );
  }

  String get label => switch(stage) {
    LessonStage.firstHalf => 'Идёт пара · до перерыва $untilBreakMinutes мин',
    LessonStage.breakTime => 'Перерыв · осталось $breakRemainingMinutes мин',
    LessonStage.secondHalf => 'Вторая половина · до конца $remainingMinutes мин',
  };
}
