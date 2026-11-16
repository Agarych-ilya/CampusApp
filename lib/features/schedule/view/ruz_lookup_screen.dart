import 'package:flutter/material.dart';
import '../data/ruz_entity_api.dart';

/// Extra read-only RUZ schedules. It never allows seats to be reserved.
class RuzLookupScreen extends StatefulWidget {
  const RuzLookupScreen({super.key,this.api});
  final RuzEntityApi? api;
  @override
  State<RuzLookupScreen> createState()=>_RuzLookupScreenState();
}

class _RuzLookupScreenState extends State<RuzLookupScreen> {
  late final RuzEntityApi _api=widget.api??RuzEntityApi();
  final _query=TextEditingController();
  String _kind='person';
  List<RuzEntity> _results=[];
  RuzEntity? _selected;
  List<RuzLesson>? _lessons;
  bool _busy=false;
  String? _error;

  @override
  void dispose(){
    _query.dispose();
    if(widget.api==null)_api.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term=_query.text.trim();
    if(_busy||term.length<2)return;
    setState((){
      _busy=true;_error=null;_results=[];_selected=null;_lessons=null;
    });
    try {
      final data=await _api.search(_kind,term);
      if(mounted)setState(()=>_results=data);
    } catch(error) {
      if(mounted)setState(()=>_error=error.toString()
        .replaceFirst('Exception: ',''));
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _open(RuzEntity entity) async {
    if(_busy)return;
    setState((){
      _busy=true;_selected=entity;_lessons=null;_error=null;
    });
    try {
      final now=DateTime.now();
      final week=now.subtract(Duration(days:now.weekday-1));
      final lessons=await _api.schedule(entity,week,
        week.add(const Duration(days:13)));
      if(mounted && _selected?.id==entity.id){
        setState(()=>_lessons=lessons);
      }
    } catch(error) {
      if(mounted)setState(()=>_error=error.toString()
        .replaceFirst('Exception: ',''));
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Расписание РУЗ')),
    body:ListView(
      padding:const EdgeInsets.fromLTRB(18,12,18,28),
      children:[
        const Text('Поиск по преподавателю или аудитории. '
          'Данные только для просмотра — бронирование '
          'мест здесь недоступно.'),
        const SizedBox(height:12),
        SegmentedButton<String>(
          selected:{_kind},
          segments:const [
            ButtonSegment(value:'person',label:Text('Преподаватель'),
              icon:Icon(Icons.person_search_outlined)),
            ButtonSegment(value:'auditorium',label:Text('Аудитория'),
              icon:Icon(Icons.meeting_room_outlined)),
          ],
          onSelectionChanged:(value)=>setState((){
            _kind=value.first;_results=[];_lessons=null;_selected=null;
          }),
        ),
        const SizedBox(height:12),
        TextField(
          controller:_query,
          decoration:InputDecoration(
            labelText:_kind=='person'?'Фамилия':'Название аудитории',
            border:const OutlineInputBorder(),
            suffixIcon:IconButton(
              tooltip:'Искать в РУЗ',
              onPressed:_busy?null:_search,
              icon:const Icon(Icons.search),
            ),
          ),
          onSubmitted:(_)=>_search(),
        ),
        const SizedBox(height:10),
        if(_busy)const LinearProgressIndicator(),
        if(_error!=null)
          Padding(padding:const EdgeInsets.all(8),
            child:Text(_error!,style:TextStyle(
              color:Theme.of(context).colorScheme.error))),
        if(_selected==null)...[
          for(final item in _results)
            ListTile(
              title:Text(item.label),
              subtitle:item.description.isNotEmpty
                ? Text(item.description):null,
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>_open(item),
            ),
          if(!_busy&&_results.isEmpty)
            const Padding(padding:EdgeInsets.all(12),
              child:Text('Введите запрос и выберите результат РУЗ.')),
        ]else...[
          TextButton.icon(
            onPressed:()=>setState((){
              _selected=null;_lessons=null;
            }),
            icon:const Icon(Icons.arrow_back),
            label:const Text('К списку'),
          ),
          Text(_selected!.label,style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:10),
          if(_lessons!=null&&_lessons!.isEmpty)
            const Text('На ближайшие две недели занятий не найдено'),
          if(_lessons!=null)
            for(final lesson in _lessons!)
              Card(child:ListTile(
                title:Text(lesson.subject),
                subtitle:Text([
                  lesson.date,lesson.time,lesson.room,lesson.group,
                  lesson.teacher,lesson.type,
                ].where((x)=>x.isNotEmpty).join(' · ')),
              )),
        ],
      ],
    ),
  );
}
