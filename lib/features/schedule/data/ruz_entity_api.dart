import 'dart:convert';
import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';

class RuzEntity {
  const RuzEntity({
    required this.id,required this.label,
    required this.description,required this.type,
  });
  final int id;
  final String label,description,type;
  factory RuzEntity.fromJson(Object? raw) {
    if(raw is! Map) throw const FormatException('Неверный объект РУЗ');
    final id=raw['id'];
    if(id is! int||id<=0||id>2147483647) {
      throw const FormatException('Неверный идентификатор РУЗ');
    }
    return RuzEntity(
      id:id,label:raw['label']?.toString()??'',
      description:raw['description']?.toString()??'',
      type:raw['type']?.toString()??'',
    );
  }
}

class RuzLesson {
  const RuzLesson({
    required this.date,required this.time,required this.subject,
    required this.type,required this.room,required this.teacher,
    required this.group,
  });
  final String date,time,subject,type,room,teacher,group;
  factory RuzLesson.fromJson(Object? raw) {
    if(raw is! Map) throw const FormatException('Неверное занятие');
    String field(String name)=>raw[name]?.toString()??'';
    return RuzLesson(
      date:field('date'),time:field('time'),
      subject:field('subject'),type:field('type'),
      room:field('room'),teacher:field('teacher'),
      group:field('group'),
    );
  }
}

class RuzEntityApi {
  RuzEntityApi({http.Client? client})
    :_client=client??http.Client(),_ownsClient=client==null;
  final http.Client _client;
  final bool _ownsClient;

  Future<List<dynamic>> _get(String path,Map<String,String> args) async {
    final url=Uri.parse(ApiConfig.baseUrl+'/schedule/ruz/'+path)
      .replace(queryParameters:args);
    final response=await _client.get(url)
      .timeout(const Duration(seconds:15));
    if(response.statusCode!=200) {
      throw Exception('РУЗ недоступен: HTTP '+response.statusCode.toString());
    }
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! List) throw const FormatException('Неверный формат РУЗ');
    return data;
  }

  Future<List<RuzEntity>> search(String kind,String term) async =>
    (await _get('search',{'type':kind,'q':term}))
      .map(RuzEntity.fromJson).toList();

  Future<List<RuzLesson>> schedule(
    RuzEntity entity,DateTime from,DateTime to,
  ) async {
    String date(DateTime x)=>x.year.toString().padLeft(4,'0')+'-'+
      x.month.toString().padLeft(2,'0')+'-'+
      x.day.toString().padLeft(2,'0');
    return (await _get('lessons',{
      'type':entity.type,'id':entity.id.toString(),
      'from':date(from),'to':date(to),
    })).map(RuzLesson.fromJson).toList();
  }

  void dispose(){if(_ownsClient)_client.close();}
}
