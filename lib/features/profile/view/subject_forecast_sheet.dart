import 'package:flutter/material.dart';

import '../data/bars_subject.dart';
import '../data/subject_grade_forecast.dart';

/// What-if calculation is local and does not modify stored BARS marks.
class SubjectForecastSheet extends StatefulWidget {
  const SubjectForecastSheet({super.key, required this.subject});
  final BarsSubject subject;
  @override
  State<SubjectForecastSheet> createState() => _SubjectForecastSheetState();
}

class _SubjectForecastSheetState extends State<SubjectForecastSheet> {
  final Map<int,int> _simulations = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = SubjectGradeForecast.calculate(
      widget.subject, simulations: _simulations,
    );
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: ListView(children: [
            Row(children: [
              const Icon(Icons.calculate_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text('Прогноз · ${widget.subject.name}',
                maxLines: 2,overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Закрыть',
                onPressed: ()=>Navigator.pop(context),
                icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            Text('Расчёт по весам КМ из БАРС. Подставленные оценки '
              'не сохраняются и не отправляются на сервер.',
              style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if(result==null)
              const Text('Недостаточно данных: нет контрольных мероприятий '
                'с числовыми весами.')
            else ...[
              Wrap(spacing: 8,runSpacing: 8,children: [
                _ForecastMetric(label:'Среднее оценённых',
                  value: result.gradedAverage==null?'—':
                    result.gradedAverage!.toStringAsFixed(2)),
                _ForecastMetric(label:'Набрано от всех КМ',
                  value:result.earnedWeightedScore.toStringAsFixed(2)),
                _ForecastMetric(label:'Осталось КМ',
                  value:'${result.remainingCount}'),
              ]),
              if(result.excludedCount>0)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('Исключено КМ без веса: '
                    '${result.excludedCount}',
                    style:theme.textTheme.bodySmall)),
              const SizedBox(height: 16),
              Text('Прогноз по порогам',
                style:theme.textTheme.titleMedium),
              for(final target in result.targets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(target.status=='guaranteed'
                    ? Icons.check_circle_outline
                    : target.status=='impossible'
                      ? Icons.block_outlined : Icons.trending_up_rounded),
                  title: Text('${target.grade} · от '
                    '${target.threshold.toStringAsFixed(1)}'),
                  subtitle: Text(switch(target.status){
                    'guaranteed'=>'Уже гарантировано при оставшихся оценках 2–5',
                    'impossible'=>'Недостижимо даже при максимуме',
                    _=>'Нужно в среднем не менее '
                      '${target.requiredRemainingAverage!.toStringAsFixed(2)} '
                      'за оставшиеся КМ',
                  }),
                ),
            ],
            const Divider(height: 26),
            Text('Смоделировать оценки',
              style:theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Можно попробовать будущие оценки и пересдачу «2». '
              'После пересдачи эффективный балл = (2 + новая оценка) / 2.',
              style:theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            for(var i=0;i<widget.subject.controls.length;i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.subject.controls[i].title,
                  maxLines: 2,overflow:TextOverflow.ellipsis),
                subtitle: Text('Вес: ${widget.subject.controls[i].weight}% · '
                  'БАРС: ${widget.subject.controls[i].grade.isEmpty
                    ? 'нет оценки' : widget.subject.controls[i].grade}'),
                trailing: Row(mainAxisSize: MainAxisSize.min,children:[
                  DropdownButton<int>(
                    key: ValueKey('bars-forecast-grade-$i'),
                    value: _simulations[i],
                    hint: const Text('—'),
                    items: [
                      for(var grade=2;grade<=5;grade++)
                        DropdownMenuItem<int>(
                          value:grade,child: Text('$grade')),
                    ],
                    onChanged:(v)=>setState((){
                      if(v!=null) _simulations[i]=v;
                    }),
                  ),
                  if(_simulations.containsKey(i))
                    IconButton(
                      tooltip: 'Сбросить КМ',
                      onPressed:()=>setState(()=>_simulations.remove(i)),
                      icon:const Icon(Icons.close,size:16),
                    ),
                ]),
              ),
            if(_simulations.isNotEmpty)
              TextButton.icon(
                onPressed:()=>setState(_simulations.clear),
                icon:const Icon(Icons.refresh),
                label:const Text('Сбросить весь сценарий'),
              ),
            const SizedBox(height: 8),
            Text('Пороги 4.2 / 3.5 / 2.5 — ориентиры калькулятора '
              'Spark, а не подтверждение итоговой оценки преподавателем.',
              style:theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({required this.label,required this.value});
  final String label,value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
      child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:Theme.of(context).textTheme.labelSmall),
          const SizedBox(height:4),
          Text(value,style:const TextStyle(
            fontSize:17,fontWeight:FontWeight.w800)),
        ]),
    ),
  );
}
