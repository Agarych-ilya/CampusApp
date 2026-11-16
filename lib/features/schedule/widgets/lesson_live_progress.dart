import 'dart:async';
import 'package:flutter/material.dart';
import '../data/lesson_break_progress.dart';

class LessonLiveProgress extends StatefulWidget {
  const LessonLiveProgress({
    super.key, required this.lessonDate, required this.time,
  });
  final DateTime lessonDate;
  final String time;
  @override
  State<LessonLiveProgress> createState()=>_LessonLiveProgressState();
}

class _LessonLiveProgressState extends State<LessonLiveProgress> {
  Timer? _refresh;

  @override
  void initState(){
    super.initState();
    _refresh=Timer.periodic(const Duration(seconds:30),(_){
      if(mounted) setState(() {});
    });
  }

  @override
  void dispose(){
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final progress=LessonBreakProgress.calculate(
      lessonDate:widget.lessonDate,time:widget.time,
    );
    if(progress==null) return const SizedBox.shrink();
    final scheme=Theme.of(context).colorScheme;
    return Padding(
      padding:const EdgeInsets.only(top:12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(progress.stage==LessonStage.breakTime
              ? Icons.free_breakfast_outlined
              : Icons.timelapse_outlined,
              color:scheme.primary,size:17),
            const SizedBox(width:7),
            Expanded(child:Text(progress.label,
              key:const ValueKey('campus-current-lesson'),
              style:TextStyle(color:scheme.onSurface,
                fontSize:12,fontWeight:FontWeight.w700))),
          ]),
          const SizedBox(height:7),
          ClipRRect(
            borderRadius:BorderRadius.circular(6),
            child:LinearProgressIndicator(
              key:const ValueKey('campus-lesson-progress'),
              value:progress.progress,
              minHeight:5,
              backgroundColor:scheme.primary.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
