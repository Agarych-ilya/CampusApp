import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'cloud_api.dart';

/// Local-only Cloud Campus files. This does not use the backend or an
/// externally readable download directory. Removing app data removes files.
///
/// Directory provider can be overridden in tests; production uses the OS
/// application-support sandbox (Android app-specific storage).
class LocalCloudStore {
  LocalCloudStore({Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider ?? _defaultRoot;

  final Future<Directory> Function() _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/campus_cloud_private');
  }

  static const _maxFileBytes = 20 * 1024 * 1024;

  Future<Directory> _root() async {
    final directory = await _rootProvider();
    await directory.create(recursive: true);
    return directory;
  }

  Future<Map<String, dynamic>> _read() async {
    final root = await _root();
    final file = File('${root.path}/index.json');
    if (!await file.exists()) {
      return {'nextId': -1, 'files': <dynamic>[], 'folders': <dynamic>[]};
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['files'] is! List ||
        decoded['folders'] is! List || decoded['nextId'] is! int) {
      throw const FormatException('Локальный каталог повреждён');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _write(Map<String, dynamic> index) async {
    final root = await _root();
    final temp = File('${root.path}/index.tmp');
    final target = File('${root.path}/index.json');
    await temp.writeAsString(jsonEncode(index), flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }

  int _nextId(Map<String, dynamic> index) {
    final id = index['nextId'] as int;
    index['nextId'] = id - 1;
    return id;
  }

  String _name(String name) {
    final result = name.trim();
    if (result.isEmpty || result.length > 160 ||
        result == '.' || result == '..' ||
        RegExp(r'[\\/:*?"<>|\x00-\x1f]').hasMatch(result)) {
      throw const FormatException('Некорректное название файла или папки');
    }
    return result;
  }

  String _extension(String name) {
    final separator = name.lastIndexOf('.');
    if (separator < 0) return '';
    final ext = name.substring(separator + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,10}$').hasMatch(ext) ? '.$ext' : '';
  }

  String _mime(String name) {
    final extension = _extension(name);
    switch (extension) {
      case '.png': return 'image/png';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.gif': return 'image/gif';
      case '.webp': return 'image/webp';
      case '.pdf': return 'application/pdf';
      case '.txt': return 'text/plain';
      case '.zip': return 'application/zip';
      default: return 'application/octet-stream';
    }
  }

  String _randomBlob(String name) {
    final secure = Random.secure();
    final randomId = List.generate(16,
      (_) => secure.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return 'item_$randomId${_extension(name)}';
  }

  Future<List<CloudFile>> files({
    String query = '', int? folderId, bool rootOnly = false,
  }) async {
    final root = await _root();
    final index = await _read();
    return (index['files'] as List).whereType<Map>().where((entry) {
      final name = entry['name']?.toString() ?? '';
      final inFolder = folderId != null
          ? entry['folderId'] == folderId
          : !rootOnly || entry['folderId'] == null;
      return inFolder && name.toLowerCase().contains(query.toLowerCase());
    }).map((entry) {
      final name = entry['name'] as String;
      final blob = entry['blob'] as String;
      final path = '${root.path}/$blob';
      final mime = _mime(name);
      return CloudFile(
        id: (entry['id'] as num).toInt(),
        name: name,
        available: File(path).existsSync(),
        size: (entry['size'] as num).toInt(),
        mime: mime,
        folderId: (entry['folderId'] as num?)?.toInt(),
        visibility: CloudVisibility.private,
        group: null,
        mine: true,
        saved: false,
        image: mime.startsWith('image/'),
        localPath: path,
      );
    }).toList();
  }

  Future<List<CloudFolder>> folders({String query = ''}) async {
    final index = await _read();
    return (index['folders'] as List).whereType<Map>().where((entry) =>
        (entry['name']?.toString() ?? '')
            .toLowerCase().contains(query.toLowerCase())).map((entry) =>
        CloudFolder(
          id: (entry['id'] as num).toInt(),
          name: entry['name'] as String,
          visibility: CloudVisibility.private,
          group: null,
          mine: true,
          local: true,
        )).toList();
  }

  Future<CloudFolder> createFolder(String name) async {
    final index = await _read();
    final clean = _name(name);
    final id = _nextId(index);
    (index['folders'] as List).add({'id': id, 'name': clean});
    await _write(index);
    return CloudFolder(
      id: id, name: clean,
      visibility: CloudVisibility.private,
      group: null, mine: true, local: true,
    );
  }

  Future<void> renameFolder(int id, String name) async {
    final index = await _read();
    final folder = (index['folders'] as List)
        .whereType<Map>().where((item) => item['id'] == id);
    if (folder.isEmpty) throw const FileSystemException('Папка не найдена');
    folder.first['name'] = _name(name);
    await _write(index);
  }

  Future<void> renameFile(int id, String newName) async {
    final index = await _read();
    final records = (index['files'] as List)
        .whereType<Map>().where((item) => item['id'] == id);
    if (records.isEmpty) throw const FileSystemException('Файл не найден');
    final file = records.first;
    final cleaned = _name(newName);
    if (_extension(cleaned) != _extension(file['name'] as String)) {
      throw const FormatException('Расширение файла менять нельзя');
    }
    file['name'] = cleaned;
    await _write(index);
  }

  Future<void> deleteFolder(int id) async {
    final index = await _read();
    if ((index['files'] as List)
        .whereType<Map>().any((item) => item['folderId'] == id)) {
      throw const FileSystemException('Сначала перемести файлы из папки');
    }
    (index['folders'] as List).removeWhere(
        (item) => item is Map && item['id'] == id);
    await _write(index);
  }

  Future<void> moveFile(int id, int? folderId) async {
    final index = await _read();
    if (folderId != null && !(index['folders'] as List)
        .whereType<Map>().any((item) => item['id'] == folderId)) {
      throw const FileSystemException('Папка не найдена на устройстве');
    }
    final files = (index['files'] as List)
        .whereType<Map>().where((item) => item['id'] == id);
    if (files.isEmpty) throw const FileSystemException('Файл не найден');
    files.first['folderId'] = folderId;
    await _write(index);
  }

  Future<CloudFile> saveFile(String path,
      {String? name, int? folderId}) async {
    final source = File(path);
    final size = await source.length();
    if (size <= 0 || size > _maxFileBytes) {
      throw const FileSystemException('Файл должен быть от 1 байта до 20 МБ');
    }
    final clean = _name(name ?? source.uri.pathSegments.last);
    final index = await _read();
    if (folderId != null && !(index['folders'] as List)
        .whereType<Map>().any((item) => item['id'] == folderId)) {
      throw const FileSystemException('Личная папка не найдена');
    }
    final root = await _root();
    final blob = _randomBlob(clean);
    final target = File('${root.path}/$blob');
    await source.copy(target.path);
    try {
      final id = _nextId(index);
      (index['files'] as List).add({
        'id': id, 'name': clean, 'blob': blob,
        'size': size, 'folderId': folderId,
      });
      await _write(index);
      return CloudFile(
        id: id, name: clean, available: true,
        size: size, mime: _mime(clean), folderId: folderId,
        visibility: CloudVisibility.private, group: null,
        mine: true, saved: false,
        image: _mime(clean).startsWith('image/'),
        localPath: target.path,
      );
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> deleteFile(CloudFile file) async {
    if (!file.local || file.id >= 0) {
      throw const FileSystemException('Это не локальный файл');
    }
    final index = await _read();
    final entries = index['files'] as List;
    final item = entries.whereType<Map>().where(
        (item) => item['id'] == file.id).toList();
    if (item.isEmpty) return;
    entries.removeWhere((entry) => entry is Map && entry['id'] == file.id);
    await _write(index);
    final root = await _root();
    final saved = File('${root.path}/${item.first['blob']}');
    if (await saved.exists()) await saved.delete();
  }
}
