import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '/core/config/api_config.dart';

class CloudFile {
  const CloudFile({
    required this.id,
    required this.name,
    required this.available,
  });

  final int id;
  final String name;
  final bool available;

  factory CloudFile.fromJson(Map<String, dynamic> json) {
    return CloudFile(
      id: json['id'] as int,
      name: json['name'] as String,
      available: json['available'] as bool? ?? true,
    );
  }
}

class CloudApi {
  static const String baseUrl = ApiConfig.baseUrl;

  Future<List<CloudFile>> getFiles() async {
    final response = await http.get(Uri.parse('$baseUrl/file'));

    if (response.statusCode != 200) {
      throw Exception('Не удалось получить файлы (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((json) => CloudFile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> uploadFile(String path) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/file/upload'),
    );

    request.files.add(await http.MultipartFile.fromPath('file', path));

    final response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = await response.stream.bytesToString();

      throw Exception('Ошибка загрузки (${response.statusCode}): $body');
    }
  }

  Future<void> deleteFile(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/file/$id'));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Не удалось удалить файл (${response.statusCode})');
    }
  }

  Future<void> downloadAndOpenFile(CloudFile file) async {
    final response = await http.get(
      Uri.parse('$baseUrl/file/${file.id}/download'),
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось скачать файл (${response.statusCode})');
    }

    final tempDirectory = await getTemporaryDirectory();

    final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final localFile = File('${tempDirectory.path}/$safeName');

    await localFile.writeAsBytes(response.bodyBytes, flush: true);

    final result = await OpenFilex.open(localFile.path);

    if (result.type != ResultType.done) {
      throw Exception('Не удалось открыть файл: ${result.message}');
    }
  }
}
