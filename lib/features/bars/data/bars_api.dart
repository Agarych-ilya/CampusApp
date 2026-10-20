import '../model/bars_student.dart';

class BarsApi {
  const BarsApi();

  Future<BarsStudent> getCurrentStudent() async {
    throw UnimplementedError('Официальный API БАРС пока не подключён');
  }

  Future<List<dynamic>> getGrades() async {
    throw UnimplementedError('Официальный API БАРС пока не подключён');
  }

  Future<List<dynamic>> getSubjects() async {
    throw UnimplementedError('Официальный API БАРС пока не подключён');
  }

  Future<List<dynamic>> getAttendance() async {
    throw UnimplementedError('Официальный API БАРС пока не подключён');
  }
}
