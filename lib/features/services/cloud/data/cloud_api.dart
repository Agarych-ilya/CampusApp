import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';

/// Scope is enforced by backend; this is only UI metadata.
enum CloudVisibility {
  private('private', 'Личное'),
  group('group', 'Моя группа'),
  public('public', 'Всем');

  const CloudVisibility(this.key, this.label);
  final String key;
  final String label;

  static CloudVisibility parse(String? value) {
    return values.firstWhere(
      (item) => item.key == value,
      orElse: () => CloudVisibility.private,
    );
  }
}

class CloudFile {
  const CloudFile({
    required this.id,
    required this.name,
    required this.available,
    required this.size,
    required this.mime,
    required this.folderId,
    required this.visibility,
    required this.group,
    required this.mine,
    required this.saved,
    required this.image,
  });

  final int id;
  final String name;
  final bool available;
  final int size;
  final String mime;
  final int? folderId;
  final CloudVisibility visibility;
  final String? group;
  final bool mine;
  final bool saved;
  final bool image;

  factory CloudFile.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Неверные данные файла');
    return CloudFile(
      id: (value['id'] as num).toInt(),
      name: value['name']?.toString() ?? 'Без имени',
      available: value['available'] != false,
      size: (value['size'] as num?)?.toInt() ?? 0,
      mime: value['mime']?.toString() ?? '',
      folderId: (value['folderId'] as num?)?.toInt(),
      visibility: CloudVisibility.parse(value['visibility']?.toString()),
      group: value['group']?.toString(),
      mine: value['mine'] == true,
      saved: value['saved'] == true,
      image: value['image'] == true,
    );
  }
}

class CloudFolder {
  const CloudFolder({
    required this.id,
    required this.name,
    required this.visibility,
    required this.group,
    required this.mine,
  });
  final int id;
  final String name;
  final CloudVisibility visibility;
  final String? group;
  final bool mine;

  factory CloudFolder.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Неверные данные папки');
    return CloudFolder(
      id: (value['id'] as num).toInt(),
      name: value['name']?.toString() ?? '',
      visibility: CloudVisibility.parse(value['visibility']?.toString()),
      group: value['group']?.toString(),
      mine: value['mine'] == true,
    );
  }
}

class CloudApi {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String _base = '$baseUrl/cloud';

  Future<Map<String, String>> _headers({bool write = false}) async {
    await ListingsApi.instance.ensureSession();
    if (write) return ListingsApi.instance.studyAuthHeaders();
    return ListingsApi.instance.studyReadHeaders;
  }

  Exception _error(http.Response r) {
    try {
      final payload = jsonDecode(utf8.decode(r.bodyBytes));
      if (payload is Map) {
        final message = payload['message'];
        if (message is String) return Exception(message);
        if (message is List) return Exception(message.join(', '));
      }
    } catch (_) {}
    if (r.statusCode == 401 || r.statusCode == 403) {
      return Exception('Подтверди вход в БАРС для работы с облаком');
    }
    return Exception('Ошибка Cloud Campus (HTTP ${r.statusCode})');
  }

  Future<Object?> _request(String method, String path,
      {Map<String, Object?>? body, bool write = false}) async {
    final request = http.Request(method, Uri.parse('$_base$path'));
    request.headers.addAll(await _headers(write: write));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 30)),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response);
    }
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<CloudFile>> getFiles({
    String mode = 'mine',
    String query = '',
    int? folderId,
  }) async {
    final uri = Uri.parse('$_base/files').replace(queryParameters: {
      'mode': mode,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (folderId != null) 'folderId': '$folderId',
    });
    final response = await http.get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw _error(response);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const FormatException('Неверный каталог файлов');
    return data.map(CloudFile.fromJson).toList();
  }

  Future<List<CloudFolder>> getFolders({String mode = 'mine'}) async {
    final data = await _request('GET', '/folders?mode=$mode');
    if (data is! List) throw const FormatException('Неверный список папок');
    return data.map(CloudFolder.fromJson).toList();
  }

  Future<CloudFolder> createFolder(
    String name, CloudVisibility visibility,
  ) async {
    final data = await _request(
      'POST', '/folders', write: true,
      body: {'name': name.trim(), 'visibility': visibility.key},
    );
    return CloudFolder.fromJson(data);
  }

  Future<CloudFolder> editFolder(
    CloudFolder folder, String name, CloudVisibility visibility,
  ) async {
    final data = await _request(
      'PATCH', '/folders/${folder.id}', write: true,
      body: {'name': name.trim(), 'visibility': visibility.key},
    );
    return CloudFolder.fromJson(data);
  }

  Future<void> deleteFolder(int id) async {
    await _request('DELETE', '/folders/$id', write: true);
  }

  Future<void> uploadFile(
    String path, {int? folderId, CloudVisibility visibility = CloudVisibility.private}
  ) async {
    final request = http.MultipartRequest(
      'POST', Uri.parse('$_base/upload'),
    );
    request.headers.addAll(await _headers(write: true));
    if (folderId != null) request.fields['folderId'] = '$folderId';
    request.fields['visibility'] = visibility.key;
    request.files.add(await http.MultipartFile.fromPath('file', path));
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 90)),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response);
    }
  }

  Future<void> changeVisibility(
    int id, CloudVisibility visibility,
  ) async {
    await _request(
      'PATCH', '/files/$id/visibility', write: true,
      body: {'visibility': visibility.key},
    );
  }

  Future<void> saveFile(int id, {int? folderId}) async {
    await _request('POST', '/files/$id/save',
      write: true, body: {'folderId': folderId});
  }

  Future<void> unsaveFile(int id) async {
    await _request('DELETE', '/files/$id/save', write: true);
  }

  Future<void> moveFile(int id, {int? folderId}) async {
    await _request('PATCH', '/files/$id/move',
      write: true, body: {'folderId': folderId});
  }

  Future<Uri> createShareLink(int id) async {
    final value = await _request('POST', '/files/$id/link', write: true);
    if (value is! Map || value['token'] is! String) {
      throw const FormatException('Ссылка не создана');
    }
    final token = value['token'] as String;
    final publicUrl = value['url'];
    if (publicUrl is String && publicUrl.startsWith('https://')) {
      final uri = Uri.tryParse(publicUrl);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri;
      }
    }
    return Uri.parse('$_base/s/${Uri.encodeComponent(token)}');
  }

  Future<void> revokeShareLink(int id) async {
    await _request('DELETE', '/files/$id/link', write: true);
  }

  Future<void> deleteFile(int id) async {
    await _request('DELETE', '/files/$id', write: true);
  }

  Future<Uint8List> previewBytes(CloudFile file) async {
    if (!file.image) throw Exception('Для этого файла нет изображения');
    final response = await http.get(
      Uri.parse('$_base/files/${file.id}/preview'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) throw _error(response);
    return response.bodyBytes;
  }

  Future<void> downloadAndOpenFile(CloudFile file) async {
    if (!file.available) throw Exception('Файл отсутствует на сервере');
    final response = await http.get(
      Uri.parse('$_base/files/${file.id}/download'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) throw _error(response);
    final directory = await getTemporaryDirectory();
    final safe = file.name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final local = File('${directory.path}/cloud_${file.id}_$safe');
    await local.writeAsBytes(response.bodyBytes, flush: true);
    final result = await OpenFilex.open(local.path);
    if (result.type != ResultType.done) {
      throw Exception('Не удалось открыть файл: ${result.message}');
    }
  }
}
