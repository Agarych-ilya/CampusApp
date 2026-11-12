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
    this.localPath,
  });

  /// A local-only item is stored inside the app sandbox, never in Campus Cloud.
  final String? localPath;
  bool get local => localPath != null;

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
    this.local = false,
  });
  final bool local;
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

class CloudMigrationItem {
  const CloudMigrationItem({
    required this.id,
    required this.name,
    required this.size,
    required this.owned,
  });

  final int id;
  final String name;
  final int size;
  /// A saved bookmark can be copied locally, but its foreign original stays.
  final bool owned;

  factory CloudMigrationItem.fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! num || value['name'] is! String ||
        value['size'] is! num || value['owned'] is! bool) {
      throw const FormatException('Некорректный список файлов для переноса');
    }
    final id = (value['id'] as num).toInt();
    final size = (value['size'] as num).toInt();
    final name = value['name'] as String;
    if (id <= 0 || size <= 0 || size > 20 * 1024 * 1024 ||
        name.isEmpty) {
      throw const FormatException('Невозможно перенести этот файл');
    }
    return CloudMigrationItem(
      id: id, name: name, size: size,
      owned: value['owned'] as bool,
    );
  }
}

class CloudFolderMigration {
  const CloudFolderMigration({
    required this.id,
    required this.name,
    required this.files,
  });

  final int id;
  final String name;
  final List<CloudMigrationItem> files;

  factory CloudFolderMigration.fromJson(Object? value) {
    if (value is! Map || value['folderId'] is! num ||
        value['name'] is! String || value['files'] is! List) {
      throw const FormatException('Некорректная схема переноса папки');
    }
    final files = (value['files'] as List)
        .map(CloudMigrationItem.fromJson).toList();
    if (files.length > 500 ||
        files.map((item) => item.id).toSet().length != files.length) {
      throw const FormatException('Повторяющиеся файлы в папке');
    }
    return CloudFolderMigration(
      id: (value['folderId'] as num).toInt(),
      name: value['name'] as String,
      files: files,
    );
  }
}

/// Server-side Cloud Campus limits and current usage for the BARS student.
/// Device-only personal documents do not consume this quota.
class CloudQuota {
  const CloudQuota({
    required this.usedBytes,
    required this.usedFiles,
    required this.usedFolders,
    required this.maxFileBytes,
    required this.maxImageBytes,
    required this.maxStorageBytes,
    required this.maxFiles,
    required this.maxFolders,
  });

  static const int defaultMaxFileBytes = 20 * 1024 * 1024;
  static const int defaultMaxImageBytes = 5 * 1024 * 1024;

  final int usedBytes;
  final int usedFiles;
  final int usedFolders;
  final int maxFileBytes;
  final int maxImageBytes;
  final int maxStorageBytes;
  final int maxFiles;
  final int maxFolders;

  int get remainingBytes =>
      usedBytes >= maxStorageBytes ? 0 : maxStorageBytes - usedBytes;

  double get usedFraction => maxStorageBytes <= 0
      ? 0.0 : (usedBytes / maxStorageBytes).clamp(0.0, 1.0).toDouble();

  factory CloudQuota.fromJson(Object? value) {
    if (value is! Map || value['limits'] is! Map) {
      throw const FormatException('Некорректная информация о лимитах облака');
    }
    final limits = value['limits'] as Map;
    int amount(Map from, String key) {
      final result = from[key];
      if (result is! num || result < 0 || !result.isFinite ||
          result.toInt() != result) {
        throw const FormatException('Некорректные лимиты облака');
      }
      return result.toInt();
    }
    final quota = CloudQuota(
      usedBytes: amount(value, 'usedBytes'),
      usedFiles: amount(value, 'usedFiles'),
      usedFolders: amount(value, 'usedFolders'),
      maxFileBytes: amount(limits, 'fileBytes'),
      maxImageBytes: amount(limits, 'imageBytes'),
      maxStorageBytes: amount(limits, 'totalBytes'),
      maxFiles: amount(limits, 'files'),
      maxFolders: amount(limits, 'folders'),
    );
    if (quota.maxFileBytes == 0 || quota.maxImageBytes == 0 ||
        quota.maxStorageBytes == 0 || quota.maxFiles == 0 ||
        quota.maxFolders == 0) {
      throw const FormatException('Нулевые лимиты облака');
    }
    return quota;
  }

  /// Check a full multi-file selection before uploading anything.
  /// The backend remains the authority in case another client uploads
  /// files concurrently.
  void validateBatch(List<({int size, bool image})> selection) {
    if (selection.isEmpty) return;
    var totalBytes = 0;
    for (final item in selection) {
      validateUpload(item.size, image: item.image);
      totalBytes += item.size;
    }
    if (usedFiles + selection.length > maxFiles) {
      throw Exception(
        'В облаке не хватает свободных слотов: '
        '${maxFiles - usedFiles} из $maxFiles',
      );
    }
    if (totalBytes > maxStorageBytes - usedBytes) {
      throw Exception(
        'Недостаточно места для всех выбранных файлов: '
        'свободно ${((maxStorageBytes - usedBytes) / (1024 * 1024)).toStringAsFixed(1)} МБ',
      );
    }
  }

  /// Helpful client-side preflight. Backend still checks all limits on upload.
  void validateUpload(int size, {required bool image}) {
    if (size <= 0) {
      throw Exception('Нельзя загрузить пустой файл');
    }
    final singleLimit = image ? maxImageBytes : maxFileBytes;
    if (size > singleLimit) {
      throw Exception(image
          ? 'Изображение превышает лимит 5 МБ'
          : 'Файл превышает лимит 20 МБ');
    }
    if (usedFiles >= maxFiles) {
      throw Exception('Лимит облака: не больше $maxFiles файлов');
    }
    if (size > maxStorageBytes - usedBytes) {
      throw Exception('Недостаточно свободного места в Cloud Campus');
    }
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

  Future<CloudQuota> getQuota() async {
    final response = await _request('GET', '/quota');
    return CloudQuota.fromJson(response);
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

  Future<List<CloudFolder>> getFolders({
    String mode = 'mine',
    String query = '',
  }) async {
    final uri = Uri(path: '/folders', queryParameters: {
      'mode': mode,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    final data = await _request('GET', uri.toString());
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

  /// A rename must not accidentally change sharing permissions.
  Future<CloudFolder> renameFolder(int id, String name) async {
    final data = await _request(
      'PATCH', '/folders/$id', write: true,
      body: {'name': name.trim()},
    );
    return CloudFolder.fromJson(data);
  }

  /// Access changes are separate from folder naming.
  Future<CloudFolder> changeFolderVisibility(
    int id, CloudVisibility visibility,
  ) async {
    final data = await _request(
      'PATCH', '/folders/$id', write: true,
      body: {'visibility': visibility.key},
    );
    return CloudFolder.fromJson(data);
  }

  /// CSRF-protected manifest of every server file and bookmark in a folder.
  Future<CloudFolderMigration> folderMigrationManifest(int id) async {
    final value = await _request(
      'GET', '/folders/$id/migration', write: true,
    );
    return CloudFolderMigration.fromJson(value);
  }

  /// Called only after verified durable local copies of every manifest item.
  /// The backend rejects changes in the folder's file ID set.
  Future<void> finishFolderMigration(
    int id, List<int> copiedFileIds,
  ) async {
    await _request(
      'POST', '/folders/$id/migrate-to-device', write: true,
      body: {'fileIds': copiedFileIds},
    );
  }

  Future<void> deleteFolder(int id) async {
    await _request('DELETE', '/folders/$id', write: true);
  }

  Future<void> uploadFile(
    String path, {
    int? folderId,
    CloudVisibility visibility = CloudVisibility.private,
    String? filename,
  }) async {
    final size = await File(path).length();
    final name = (filename ?? path).toLowerCase();
    final image = name.endsWith('.png') || name.endsWith('.jpg') ||
        name.endsWith('.jpeg') || name.endsWith('.gif') ||
        name.endsWith('.webp') || name.endsWith('.bmp');
    final limit = image
        ? CloudQuota.defaultMaxImageBytes : CloudQuota.defaultMaxFileBytes;
    if (size <= 0 || size > limit) {
      throw Exception(image
          ? 'Изображение — максимум 5 МБ'
          : 'Один файл — максимум 20 МБ');
    }
    final request = http.MultipartRequest(
      'POST', Uri.parse('$_base/upload'),
    );
    request.headers.addAll(await _headers(write: true));
    if (folderId != null) request.fields['folderId'] = '$folderId';
    request.fields['visibility'] = visibility.key;
    request.files.add(await http.MultipartFile.fromPath(
      'file', path, filename: filename,
    ));
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

  Future<void> renameFile(int id, String name) async {
    await _request('PATCH', '/files/$id/name',
      write: true, body: {'name': name.trim()});
  }

  Future<Uri> createFolderShareLink(int id) async {
    final value = await _request('POST', '/folders/$id/link', write: true);
    if (value is! Map || value['token'] is! String) {
      throw const FormatException('Не удалось получить ссылку на папку');
    }
    final publicUrl = value['url'];
    if (publicUrl is String && publicUrl.startsWith('https://')) {
      final parsed = Uri.tryParse(publicUrl);
      if (parsed != null && parsed.host.isNotEmpty) return parsed;
    }
    return Uri.parse('$_base/f/${Uri.encodeComponent(value['token'] as String)}');
  }

  Future<void> revokeFolderShareLink(int id) async {
    await _request('DELETE', '/folders/$id/link', write: true);
  }

  Future<void> deleteFile(int id) async {
    await _request('DELETE', '/files/$id', write: true);
  }

  /// Explicitly download a server-owned item into a temporary file,
  /// for an opt-in migration to local-only private storage.
  Future<File> downloadToTemporary(CloudFile file) async {
    final response = await http.get(
      Uri.parse('$_base/files/${file.id}/download'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) throw _error(response);
    if (response.bodyBytes.length > 20 * 1024 * 1024) {
      throw Exception('Лимит файла: 20 МБ');
    }
    final dir = await getTemporaryDirectory();
    final safe = file.name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final target = File(
      '${dir.path}/cloud_migrate_${DateTime.now().microsecondsSinceEpoch}_$safe',
    );
    await target.writeAsBytes(response.bodyBytes, flush: true);
    return target;
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
