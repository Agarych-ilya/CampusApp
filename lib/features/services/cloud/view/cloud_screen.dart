import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '/features/services/style/service_palette.dart';
import '../data/cloud_api.dart';
import '../data/local_cloud_store.dart';
import '../data/yandex_disk_importer.dart';

class CloudScreen extends StatefulWidget {
  const CloudScreen({super.key, this.api, this.localStore, this.importer});

  /// Optional API injection for widget tests and offline previews.
  final CloudApi? api;
  final LocalCloudStore? localStore;
  final YandexDiskImporter? importer;

  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen> {
  late final CloudApi _api;
  late final LocalCloudStore _local;
  late final YandexDiskImporter _yandex;
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<CloudFile> _files = [];
  List<CloudFolder> _folders = [];
  CloudFolder? _currentFolder;
  bool _loading = true;
  bool _busy = false;
  String? _migrationStatus;
  String? _error;
  int _requestId = 0;

  bool get _isSearching => _search.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? CloudApi();
    _local = widget.localStore ?? LocalCloudStore();
    _yandex = widget.importer ?? YandexDiskImporter();
    _load();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) _load();
      });
      setState(() {});
    });
  }

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _search.dispose();
    if (widget.importer == null) _yandex.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      final folder = q.isEmpty ? _currentFolder : null;
      final localFiles = await _local.files(
        query: q,
        folderId: folder?.local == true ? folder?.id : null,
        rootOnly: q.isEmpty && folder == null,
      );
      final localFolders = folder == null
          ? await _local.folders(query: q) : <CloudFolder>[];

      var remoteFiles = <CloudFile>[];
      var remoteFolders = <CloudFolder>[];
      final pendingServerIds = await _local.pendingServerFolderIds();
      String? remoteError;
      try {
        if (folder?.local != true) {
          remoteFiles = await _api.getFiles(
            mode: 'search',
            query: q,
            folderId: folder?.id,
          );
        }
        if (folder == null) {
          remoteFolders = (await _api.getFolders(mode: 'all', query: q))
              .where((item) =>
                  !pendingServerIds.contains(item.id) ||
                  item.visibility != CloudVisibility.private)
              .toList();
        }
      } catch (error) {
        remoteError = _cleanError(error);
      }
      if (!mounted || request != _requestId) return;
      setState(() {
        _files = [
          if (folder == null || folder.local) ...localFiles,
          ...remoteFiles,
        ];
        _folders = [...localFolders, ...remoteFolders];
        _loading = false;
        _error = remoteError != null &&
            _files.isEmpty && _folders.isEmpty ? remoteError : null;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : null,
      ));
  }

  Future<void> _perform(
    Future<void> Function() operation, String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      _message(success);
      await _load();
    } catch (error) {
      _message(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<CloudVisibility?> _pickVisibility({
    CloudVisibility current = CloudVisibility.private,
  }) async {
    return showModalBottomSheet<CloudVisibility>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Кто может видеть?',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Доступ проверяется сервером через БАРС'),
              ),
              for (final access in CloudVisibility.values)
                ListTile(
                  leading: Icon(_scopeIcon(access)),
                  title: Text(access.label),
                  subtitle: Text(_scopeDescription(access)),
                  trailing: access == current
                      ? const Icon(Icons.check, color: ServicePalette.accent)
                      : null,
                  onTap: () => Navigator.pop(context, access),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _FolderNameDialog(
        title: 'Новая папка',
        actionText: 'Создать',
      ),
    );
    if (!mounted || name == null) return;
    final visibility = await _pickVisibility();
    if (!mounted || visibility == null) return;
    await _perform(() async {
      if (visibility == CloudVisibility.private) {
        await _local.createFolder(name);
      } else {
        await _api.createFolder(name, visibility);
      }
    }, visibility == CloudVisibility.private
        ? 'Личная папка создана на устройстве'
        : 'Папка создана в общем облаке');
  }

  Future<void> _renameFolder(CloudFolder folder) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: 'Переименовать папку',
        actionText: 'Сохранить',
        initialName: folder.name,
      ),
    );
    if (!mounted || name == null || name == folder.name) return;
    await _perform(
      () async {
        if (folder.local) {
          await _local.renameFolder(folder.id, name);
        } else {
          await _api.renameFolder(folder.id, name);
        }
      },
      'Название папки изменено',
    );
  }

  Future<void> _renameFile(CloudFile file) async {
    if (!file.mine) {
      _message('Изменять название может только владелец файла', error: true);
      return;
    }
    final nextName = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: 'Переименовать файл',
        actionText: 'Сохранить',
        initialName: file.name,
      ),
    );
    if (!mounted || nextName == null || nextName == file.name) return;
    await _perform(() async {
      if (file.local) {
        await _local.renameFile(file.id, nextName);
      } else {
        await _api.renameFile(file.id, nextName);
      }
    }, 'Название файла изменено');
  }

  Future<void> _createFolderLink(CloudFolder folder) async {
    if (folder.local) {
      _message(
        'Эта папка хранится только на телефоне. '
        'Для ссылки создай общую папку и загрузи в неё файлы.',
      );
      return;
    }
    if (!await _confirm(
      'Поделиться ссылкой на папку?',
      'Все, у кого есть ссылка, смогут просматривать список и скачивать '
      'файлы папки «${folder.name}», даже без входа в CampusApp.',
    )) return;
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final uri = await _api.createFolderShareLink(folder.id);
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (!mounted) return;
      _message('Ссылка на папку скопирована');
      if (['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
        _message('Для других устройств нужен публичный HTTPS-адрес backend.');
      }
    } catch (error) {
      _message(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeFolderLink(CloudFolder folder) async {
    if (folder.local) return;
    if (!await _confirm(
      'Отозвать ссылку на папку?',
      'Ранее отправленная ссылка перестанет работать.',
    )) return;
    await _perform(
      () => _api.revokeFolderShareLink(folder.id),
      'Ссылка на папку отозвана',
    );
  }

  Future<void> _changeFolderAccess(CloudFolder folder) async {
    if (_busy) return;
    final access = await _pickVisibility(current: folder.visibility);
    if (!mounted || access == null ||
        (access == folder.visibility && !(access == CloudVisibility.private &&
            !folder.local))) return;
    if (folder.local) {
      if (access == CloudVisibility.private) return;
      await _publishLocalFolder(folder, access);
      return;
    }
    if (access == CloudVisibility.private) {
      await _moveFolderToDevice(folder);
      return;
    }
    await _perform(
      () async { await _api.changeFolderVisibility(folder.id, access); },
      'Доступ к папке: ${access.label.toLowerCase()}',
    );
  }

  /// Do not remove anything on the server before every file has been
  /// downloaded, checked and committed to the app-private local store.
  Future<void> _moveFolderToDevice(CloudFolder folder) async {
    final approved = await _confirm(
      'Сделать папку личной?',
      'Все файлы папки «${folder.name}» будут сохранены на этом устройстве. '
      'После успешного копирования серверная папка и её файлы удалятся, '
      'все ссылки перестанут работать. Сохранённые чужие материалы '
      'скопируются, но чужие оригиналы не удалятся. '
      'Личные файлы не появятся на другом телефоне и могут пропасть '
      'при удалении приложения. Продолжить?',
    );
    if (!mounted || !approved) return;
    await _perform(() async {
      final manifest = await _api.folderMigrationManifest(folder.id);
      if (mounted) {
        setState(() => _migrationStatus =
            'Подготовка переноса · ${manifest.files.length} файлов');
      }
      if (manifest.id != folder.id) {
        throw const FormatException('Получены данные другой папки');
      }
      final staged = <int, File>{};
      try {
        // This includes foreign bookmarks saved in the folder.
        for (final item in manifest.files) {
          final temp = await _api.downloadToTemporary(
            CloudFile(
              id: item.id,
              name: item.name,
              size: item.size,
              available: true,
              mine: item.owned,
              saved: !item.owned,
              mime: 'application/octet-stream',
              folderId: folder.id,
              visibility: folder.visibility,
              group: folder.group,
              image: false,
            ),
          );
          staged[item.id] = temp;
          if (mounted) {
            setState(() => _migrationStatus =
                'Скачано ${staged.length} из ${manifest.files.length}');
          }
          if (await temp.length() != item.size) {
            throw FileSystemException(
              'Файл скачался не полностью: ${item.name}',
            );
          }
        }

        // Idempotent if the backend was unreachable after a prior copy.
        if (mounted) setState(() => _migrationStatus =
            'Сохранение файлов на устройстве');
        await _local.importServerFolder(manifest, staged);
        if (mounted) setState(() => _migrationStatus =
            'Отзыв ссылок и удаление серверной копии');
        try {
          await _api.finishFolderMigration(
            folder.id, manifest.files.map((file) => file.id).toList(),
          );
        } catch (_) {
          throw Exception(
            'Копия папки уже сохранена на устройстве, но завершить удаление '
            'на сервере не удалось. Серверная папка и ссылки пока остались. '
            'Повтори «Настроить доступ → Личное» после проверки сети.',
          );
        }
        if (mounted && _currentFolder?.id == folder.id &&
            _currentFolder?.local == false) {
          setState(() => _currentFolder = null);
        }
      } finally {
        for (final file in staged.values) {
          if (await file.exists()) {
            try { await file.delete(); } catch (_) {}
          }
        }
      }
    }, 'Папка теперь только на устройстве. Ссылки отозваны.');
    if (mounted) setState(() => _migrationStatus = null);
  }

  Future<bool> _sameBytes(File leftFile, File rightFile) async {
    if (await leftFile.length() != await rightFile.length()) return false;
    final left = await leftFile.open();
    final right = await rightFile.open();
    try {
      while (true) {
        final a = await left.read(65536);
        final b = await right.read(65536);
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) return false;
        }
        if (a.isEmpty) return true;
      }
    } finally {
      await left.close();
      await right.close();
    }
  }

  /// Change the storage location instead of making a second visible folder.
  /// A private server staging folder allows retries without exposing a
  /// partially uploaded collection to other students.
  Future<void> _publishLocalFolder(
    CloudFolder folder, CloudVisibility access,
  ) async {
    if (_busy || access == CloudVisibility.private) return;
    final approved = await _confirm(
      'Перенести папку в облако?',
      'Файлы «${folder.name}» будут загружены и проверены на сервере. '
      'После успешной проверки локальная папка исчезнет из списка, '
      'останется одна папка с доступом «${access.label}». '
      'Если такая серверная копия уже есть, приложение сначала '
      'проверит её содержимое. Продолжить?',
    );
    if (!mounted || !approved) return;
    await _perform(() async {
      try {
        final files = await _local.files(folderId: folder.id);
        for (final file in files) {
          if (!file.available || file.localPath == null ||
              await File(file.localPath!).length() != file.size) {
            throw Exception('Не удалось прочитать файл: ${file.name}');
          }
        }

        final pendingId = await _local.pendingPublication(folder.id);
        final serverFolders = await _api.getFolders(mode: 'mine');
        CloudFolder? serverFolder;
        var existingPublishedCopy = false;

        if (pendingId != null) {
          for (final candidate in serverFolders) {
            if (candidate.id == pendingId && candidate.mine) {
              serverFolder = candidate;
              break;
            }
          }
          if (serverFolder == null) {
            throw Exception(
              'Не найдена папка незавершённого переноса на сервере. '
              'Проверь доступ к backend перед повторением.',
            );
          }
        } else {
          final existing = serverFolders.where((candidate) =>
              candidate.mine && candidate.name == folder.name &&
              candidate.visibility == access).toList();
          if (existing.length > 1) {
            throw Exception(
              'Найдено несколько общих папок с названием «${folder.name}». '
              'Переименуй лишние папки, чтобы безопасно объединить данные.',
            );
          }
          if (existing.length == 1) {
            // Legacy duplicate created by the previous copy-only behavior:
            // verify bytes before adopting the existing server folder.
            serverFolder = existing.single;
            existingPublishedCopy = true;
          } else {
            serverFolder = await _api.createFolder(
              folder.name, CloudVisibility.private,
            );
          }
          await _local.markPendingPublication(folder.id, serverFolder.id);
        }

        final destination = serverFolder!;
        if (destination.name != folder.name) {
          throw Exception('Название папки изменилось во время переноса');
        }

        var onServer = await _api.getFiles(
          mode: 'mine', folderId: destination.id,
        );
        final unmatched = [...onServer];
        for (var i = 0; i < files.length; i++) {
          final localFile = files[i];
          final index = unmatched.indexWhere((remote) =>
              remote.mine && remote.name == localFile.name &&
              remote.size == localFile.size);
          if (index >= 0) {
            unmatched.removeAt(index);
            continue;
          }
          if (existingPublishedCopy) {
            throw Exception(
              'Содержимое уже опубликованной папки отличается. '
              'Ничего не удалено. Сверь файлы вручную.',
            );
          }
          if (mounted) {
            setState(() => _migrationStatus =
                'Загрузка ${i + 1} из ${files.length}');
          }
          await _api.uploadFile(
            localFile.localPath!,
            filename: localFile.name,
            folderId: destination.id,
            visibility: CloudVisibility.private,
          );
        }
        if (unmatched.isNotEmpty) {
          throw Exception(
            'На сервере оказались дополнительные файлы. '
            'Папки не объединены, локальные данные сохранены.',
          );
        }

        onServer = await _api.getFiles(
          mode: 'mine', folderId: destination.id,
        );
        if (onServer.length != files.length) {
          throw Exception('Не все файлы появились на сервере');
        }
        final toVerify = [...onServer];
        for (var i = 0; i < files.length; i++) {
          final localFile = files[i];
          final index = toVerify.indexWhere((remote) =>
              remote.mine && remote.name == localFile.name &&
              remote.size == localFile.size && remote.available);
          if (index < 0) {
            throw Exception('Файл отсутствует на сервере: ${localFile.name}');
          }
          final remoteFile = toVerify.removeAt(index);
          if (mounted) {
            setState(() => _migrationStatus =
                'Проверка ${i + 1} из ${files.length}');
          }
          final temp = await _api.downloadToTemporary(remoteFile);
          try {
            if (!await _sameBytes(File(localFile.localPath!), temp)) {
              throw Exception(
                'Файл «${localFile.name}» отличается от загруженного. '
                'Локальная папка сохранена.',
              );
            }
          } finally {
            if (await temp.exists()) {
              try { await temp.delete(); } catch (_) {}
            }
          }
        }

        if (destination.visibility != access) {
          if (mounted) {
            setState(() => _migrationStatus = 'Открытие доступа к папке');
          }
          await _api.changeFolderVisibility(destination.id, access);
        }

        if (mounted) {
          setState(() => _migrationStatus =
              'Завершение переноса · удаление локальной копии');
        }
        await _local.finishPublishedFolder(folder.id, files, destination.id);
        if (mounted && _currentFolder?.local == true &&
            _currentFolder?.id == folder.id) {
          setState(() => _currentFolder = null);
        }
      } finally {
        if (mounted) setState(() => _migrationStatus = null);
      }
    }, 'Папка перенесена в облако. Дубликатов больше нет.');
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      ) ?? false;

  Future<void> _upload() async {
    if (_busy) return;
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      if (file.path == null) {
        _message('Не удалось получить путь файла', error: true);
        return;
      }
      CloudVisibility access = CloudVisibility.private;
      final folder = !_isSearching && _currentFolder?.mine == true
          ? _currentFolder : null;
      if (folder != null) {
        access = folder.visibility;
      } else {
        final chosen = await _pickVisibility();
        if (chosen == null) return;
        access = chosen;
      }
      await _perform(() async {
        if (access == CloudVisibility.private) {
          await _local.saveFile(
            file.path!, name: file.name,
            folderId: folder?.local == true ? folder?.id : null,
          );
        } else {
          await _api.uploadFile(
            file.path!,
            folderId: folder?.local == true ? null : folder?.id,
            visibility: access,
            filename: file.name,
          );
        }
      }, access == CloudVisibility.private
          ? 'Файл сохранён только на устройстве'
          : 'Файл загружен в Campus Cloud');
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  Future<void> _importYandex() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _YandexLinkDialog(),
    );
    if (!mounted || url == null) return;
    final folder = !_isSearching && _currentFolder?.mine == true
        ? _currentFolder : null;
    CloudVisibility visibility = folder?.visibility ?? CloudVisibility.private;
    if (folder == null) {
      final selected = await _pickVisibility();
      if (!mounted || selected == null) return;
      visibility = selected;
    }
    await _perform(() async {
      final imported = await _yandex.download(url);
      try {
        if (visibility == CloudVisibility.private) {
          await _local.saveFile(
            imported.file.path, name: imported.name,
            folderId: folder?.local == true ? folder?.id : null,
          );
        } else {
          await _api.uploadFile(
            imported.file.path,
            folderId: folder?.local == true ? null : folder?.id,
            visibility: visibility,
            filename: imported.name,
          );
        }
      } finally {
        if (await imported.file.exists()) await imported.file.delete();
      }
    }, visibility == CloudVisibility.private
        ? 'Импортировано только на устройство (папка — ZIP)'
        : 'Импортировано в Campus Cloud (папка — ZIP)');
  }

  Future<void> _save(CloudFile file) async {
    await _perform(
      () => _api.saveFile(file.id),
      '«${file.name}» сохранён в твою библиотеку',
    );
  }

  Future<void> _removeSaved(CloudFile file) async {
    await _perform(
      () => _api.unsaveFile(file.id), 'Убрано из библиотеки',
    );
  }

  Future<void> _deleteFile(CloudFile file) async {
    final confirmed = await _confirm(
      'Удалить навсегда?',
      file.local
          ? '«${file.name}» будет удалён с этого устройства без восстановления.'
          : '«${file.name}» будет удалён с сервера и исчезнет '
              'из сохранённого у других студентов.',
    );
    if (!confirmed) return;
    await _perform(() async {
      if (file.local) {
        await _local.deleteFile(file);
      } else {
        await _api.deleteFile(file.id);
      }
    }, 'Файл удалён');
  }

  Future<void> _deleteFolder(CloudFolder folder) async {
    if (!await _confirm(
      'Удалить папку?',
      'Папку «${folder.name}» можно удалить только после '
      'перемещения всех собственных файлов.',
    )) {
      return;
    }
    await _perform(() async {
      if (folder.local) {
        await _local.deleteFolder(folder.id);
      } else {
        await _api.deleteFolder(folder.id);
      }
    }, 'Папка удалена');
  }

  Future<void> _changeScope(CloudFile file) async {
    final access = await _pickVisibility(current: file.visibility);
    if (!mounted || access == null ||
        (access == file.visibility && access != CloudVisibility.private)) {
      return;
    }

    if (file.local && access == CloudVisibility.private) return;
    if (file.local) {
      if (!await _confirm(
        'Опубликовать файл?',
        '«${file.name}» будет загружен с устройства на сервер CampusApp. '
        'Локальный оригинал останется на устройстве.',
      )) return;
      await _perform(() => _api.uploadFile(
        file.localPath!, visibility: access, filename: file.name,
      ), 'Копия файла загружена на сервер');
      return;
    }
    if (access == CloudVisibility.private) {
      if (!await _confirm(
        'Переместить на устройство?',
        'Файл будет скачан на телефон и удалён с сервера CampusApp. '
        'Все ссылки и сохранения других студентов перестанут работать.',
      )) return;
      await _perform(() async {
        final temporary = await _api.downloadToTemporary(file);
        try {
          await _local.saveFile(temporary.path, name: file.name);
          await _api.deleteFile(file.id);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      }, 'Файл теперь хранится только на устройстве');
      return;
    }
    await _perform(
      () => _api.changeVisibility(file.id, access),
      'Доступ: ${access.label.toLowerCase()}',
    );
  }

  Future<void> _createLink(CloudFile file) async {
    if (_busy) return;
    if (!await _confirm(
      'Создать ссылку на файл?',
      'Любой, у кого есть ссылка, сможет скачать «${file.name}», '
      'даже если файл личный. Предыдущая ссылка перестанет работать.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final url = await _api.createShareLink(file.id);
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (!mounted) return;
      _message('Ссылка скопирована. Можно отправить другому студенту.');
      if (['localhost', '127.0.0.1', '10.0.2.2'].contains(url.host)) {
        _message('Ссылка локальная: для доступа других нужен HTTPS-адрес сервера.');
      }
    } catch (error) {
      _message(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeLink(CloudFile file) async {
    if (!await _confirm('Отозвать ссылку?',
        'Ранее созданная ссылка на «${file.name}» перестанет работать.')) {
      return;
    }
    await _perform(() => _api.revokeShareLink(file.id), 'Ссылка отозвана');
  }

  Future<void> _moveFile(CloudFile file) async {
    try {
      final folders = file.local
          ? await _local.folders()
          : (await _api.getFolders(mode: 'mine'))
              .where((folder) => folder.mine).toList();
      if (!mounted) return;
      const root = -1;
      final selection = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Переместить в папку',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Без папки'),
                onTap: () => Navigator.pop(context, root),
              ),
              for (final folder in folders)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder.name),
                  subtitle: Text(folder.visibility.label),
                  onTap: () => Navigator.pop(context, folder.id),
                ),
            ],
          ),
        ),
      );
      if (!mounted || selection == null) return;
      await _perform(() async {
        if (file.local) {
          await _local.moveFile(
            file.id, selection == root ? null : selection,
          );
        } else {
          await _api.moveFile(
            file.id, folderId: selection == root ? null : selection,
          );
        }
      }, 'Файл перемещён');
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  Future<void> _openFile(CloudFile file) async {
    if (!file.available) {
      _message('Файл отсутствует в хранилище', error: true);
      return;
    }
    if (file.image) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(file.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Закрыть',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                ),
                child: FutureBuilder<Uint8List>(
                  future: file.local
                      ? File(file.localPath!).readAsBytes()
                      : _api.previewBytes(file),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(22),
                        child: Text('Не удалось открыть: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(60),
                        child: CircularProgressIndicator(),
                      );
                    }
                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('Не удалось показать изображение'),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _download(file);
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Скачать оригинал'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      await _download(file);
    }
  }

  Future<void> _download(CloudFile file) async {
    _message('Открываем «${file.name}»…');
    try {
      if (file.local) {
        final result = await OpenFilex.open(file.localPath!);
        if (result.type != ResultType.done) {
          throw Exception('Не удалось открыть файл: ${result.message}');
        }
      } else {
        await _api.downloadAndOpenFile(file);
      }
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  void _createMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Добавить в Cloud Campus',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Учебные материалы всегда под рукой'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Загрузить файл'),
              onTap: () {
                Navigator.pop(context);
                _upload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: const Text('Импорт по ссылке Яндекс Диска'),
              subtitle: const Text('Публичный файл или папка как ZIP'),
              onTap: () {
                Navigator.pop(context);
                _importYandex();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Создать папку'),
              onTap: () {
                Navigator.pop(context);
                _createFolder();
              },
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  static IconData _scopeIcon(CloudVisibility visibility) {
    switch (visibility) {
      case CloudVisibility.private: return Icons.lock_outline;
      case CloudVisibility.group: return Icons.groups_outlined;
      case CloudVisibility.public: return Icons.public;
    }
  }

  static String _scopeDescription(CloudVisibility visibility) {
    switch (visibility) {
      case CloudVisibility.private:
        return 'Только на этом устройстве · не загружается на сервер';
      case CloudVisibility.group:
        return 'Доступно студентам твоей группы БАРС';
      case CloudVisibility.public:
        return 'Могут найти все студенты CampusApp';
    }
  }

  static String _size(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} МБ';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '$bytes Б';
  }

  static IconData _fileIcon(CloudFile file) {
    if (file.image) return Icons.image_outlined;
    final extension = file.name.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv': return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx': return Icons.slideshow_outlined;
      case 'zip':
      case 'rar': return Icons.folder_zip_outlined;
      case 'mp4': return Icons.video_file_outlined;
      case 'mp3': return Icons.audio_file_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Widget _scopeTag(CloudVisibility visibility, {
    String? group, bool local = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_scopeIcon(visibility), size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(local
            ? 'На устройстве'
            : (visibility == CloudVisibility.group &&
                    group != null && group.isNotEmpty
                ? group : visibility.label), style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        )),
      ],
    );
  }

  Widget _folderCard(CloudFolder folder) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('cloud-folder-${folder.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() => _currentFolder = folder);
          if (_isSearching) _search.clear();
          _load();
        },
        child: SizedBox(
          width: 154,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.folder_rounded, size: 34,
                      color: ServicePalette.accent),
                  const Spacer(),
                  if (folder.mine)
                    PopupMenuButton<String>(
                      tooltip: 'Настроить папку',
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (value) {
                        if (value == 'rename') _renameFolder(folder);
                        if (value == 'access') _changeFolderAccess(folder);
                        if (value == 'link') _createFolderLink(folder);
                        if (value == 'revoke') _revokeFolderLink(folder);
                        if (value == 'delete') _deleteFolder(folder);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rename', child: Text('Переименовать'),
                        ),
                        const PopupMenuItem(
                          value: 'access', child: Text('Настроить доступ'),
                        ),
                        PopupMenuItem(
                          value: 'link',
                          child: Text(folder.local
                              ? 'Как поделиться папкой?'
                              : 'Скопировать ссылку на папку'),
                        ),
                        if (!folder.local)
                          const PopupMenuItem(
                            value: 'revoke',
                            child: Text('Отозвать ссылку на папку'),
                          ),
                        const PopupMenuItem(
                          value: 'delete', child: Text('Удалить папку'),
                        ),
                      ],
                    ),
                ]),
                const SizedBox(height: 12),
                Text(folder.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                _scopeTag(folder.visibility, group: folder.group,
                    local: folder.local),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileCard(CloudFile file) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('cloud-file-${file.id}'),
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 7, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _CloudThumbnail(
                  key: ValueKey('cloud-preview-${file.id}'),
                  api: _api,
                  file: file,
                  fallbackIcon: _fileIcon(file),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      Text(_size(file.size), style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 12,
                      )),
                      const SizedBox(height: 4),
                      _scopeTag(file.visibility, group: file.group,
                          local: file.local),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Действия с файлом',
                  enabled: !_busy,
                  onSelected: (value) {
                    switch (value) {
                      case 'open': _openFile(file); break;
                      case 'download': _download(file); break;
                      case 'save': _save(file); break;
                      case 'unsave': _removeSaved(file); break;
                      case 'move': _moveFile(file); break;
                      case 'rename': _renameFile(file); break;
                      case 'scope': _changeScope(file); break;
                      case 'link': _createLink(file); break;
                      case 'revoke': _revokeLink(file); break;
                      case 'delete': _deleteFile(file); break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'open', child: Text('Открыть'),
                    ),
                    const PopupMenuItem(
                      value: 'download', child: Text('Скачать'),
                    ),
                    if (!file.mine && !file.saved)
                      const PopupMenuItem(
                        value: 'save', child: Text('Сохранить себе'),
                      ),
                    if (!file.mine && file.saved)
                      const PopupMenuItem(
                        value: 'unsave', child: Text('Убрать из моих'),
                      ),
                    if (file.mine || file.saved)
                      const PopupMenuItem(
                        value: 'move', child: Text('Переместить в папку'),
                      ),
                    if (file.mine) ...[
                      const PopupMenuItem(
                        value: 'rename', child: Text('Переименовать'),
                      ),
                      PopupMenuItem(
                        value: 'scope',
                        child: Text(file.local
                            ? 'Загрузить в общее облако'
                            : 'Настроить доступ'),
                      ),
                      if (!file.local) ...[
                        const PopupMenuItem(
                          value: 'link', child: Text('Скопировать ссылку'),
                        ),
                        const PopupMenuItem(
                          value: 'revoke', child: Text('Отозвать ссылку'),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить навсегда',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
              ]),
              if (!file.mine) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: file.saved
                      ? TextButton.icon(
                          onPressed: _busy ? null : () => _removeSaved(file),
                          icon: const Icon(Icons.bookmark_added_outlined,
                              size: 17),
                          label: const Text('Сохранено у меня'),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _save(file),
                          icon: const Icon(Icons.bookmark_add_outlined,
                              size: 17),
                          label: const Text('Сохранить себе'),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final colors = theme.colorScheme;
    final q = _search.text.trim();
    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Campus',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Обновить облако',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createMenu,
        backgroundColor: ServicePalette.accent,
        foregroundColor: Colors.white,
        icon: _busy
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
        label: const Text('Создать',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(19),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ServicePalette.accent.withValues(alpha: 0.21),
                            colors.surfaceContainerHigh,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        const Icon(Icons.cloud_done_rounded,
                            color: ServicePalette.accent, size: 38),
                        const SizedBox(width: 15),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Твои знания всегда рядом',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Сохраняй, делись с группой и находи материалы',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )),
                      ]),
                    ),
                    if (_migrationStatus != null) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        _migrationStatus!,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 19),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Поиск по файлам и папкам…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: q.isEmpty ? null : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _search.clear,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (q.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Файлы и папки: личные, группы и общедоступные',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (_currentFolder != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: const Icon(Icons.arrow_back, size: 18),
                          label: Text('Все папки / ${_currentFolder!.name}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () {
                            setState(() => _currentFolder = null);
                            _load();
                          },
                        ),
                      )
                    else
                      Row(children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _createFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Новая папка'),
                        ),
                        const SizedBox(width: 10),
                        Text('${_folders.length} папок',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant)),
                      ]),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(child: Text(
                        _isSearching ? 'Результаты поиска'
                            : _currentFolder != null
                                ? 'Файлы в папке'
                                : 'Все файлы',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900),
                      )),
                      if (!_loading)
                        Text('${_files.length + _folders.length}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                            )),
                    ]),
                    const SizedBox(height: 12),
                    // Folder cards belong to the same root file browser.
                    // Files nested in a folder are not flattened here.
                    if (_folders.isNotEmpty && _currentFolder == null) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final folder in _folders) _folderCard(folder),
                        ],
                      ),
                      if (_files.isNotEmpty) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Повторить'),
                    ),
                  ]),
                ),
              )
            else if (_files.isEmpty && _folders.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 38, 24, 140),
                  child: Column(children: [
                    Icon(_isSearching
                        ? Icons.search_off_outlined
                        : Icons.cloud_queue_outlined,
                      size: 55, color: colors.onSurfaceVariant),
                    const SizedBox(height: 15),
                    Text(_isSearching
                        ? 'Ничего не найдено'
                        : 'Здесь пока нет файлов',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    Text(_isSearching
                        ? 'Попробуй другое название'
                        : 'Загрузи файл или найди доступные учебные материалы',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _fileCard(_files[index]),
                    ),
                    childCount: _files.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}

/// Only visible images are fetched. Preview requests use the same BARS
/// session as downloads, so a private file never becomes a public URL.
class _CloudThumbnail extends StatefulWidget {
  const _CloudThumbnail({
    super.key,
    required this.api,
    required this.file,
    required this.fallbackIcon,
  });

  final CloudApi api;
  final CloudFile file;
  final IconData fallbackIcon;

  @override
  State<_CloudThumbnail> createState() => _CloudThumbnailState();
}

class _CloudThumbnailState extends State<_CloudThumbnail> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.file.image && widget.file.available) {
      _bytes = widget.file.local
          ? File(widget.file.localPath!).readAsBytes()
          : widget.api.previewBytes(widget.file);
    }
  }

  @override
  void didUpdateWidget(covariant _CloudThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.image != widget.file.image) {
      _bytes = widget.file.image && widget.file.available
          ? (widget.file.local
              ? File(widget.file.localPath!).readAsBytes()
              : widget.api.previewBytes(widget.file))
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 64,
        height: 64,
        color: ServicePalette.accent.withValues(alpha: 0.13),
        child: _bytes == null
            ? Icon(widget.fallbackIcon,
                color: ServicePalette.accent, size: 30)
            : FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Icon(widget.fallbackIcon,
                        color: colors.onSurfaceVariant);
                  }
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    cacheWidth: 128,
                    errorBuilder: (_, __, ___) =>
                        Icon(widget.fallbackIcon,
                            color: ServicePalette.accent),
                  );
                },
              ),
      ),
    );
  }
}


/// A route-owned controller: disposed only when Flutter unmounts its dialog.
/// Disposing it immediately after showDialog returns is unsafe while the
/// reverse transition / inherited widgets may still have active descendants.
class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.actionText,
    this.initialName = '',
  });

  final String title;
  final String actionText;
  final String initialName;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 160,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Название папки',
          hintText: 'Например, ТАУ · лабораторные',
          prefixIcon: Icon(Icons.folder_outlined),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.actionText),
        ),
      ],
    );
  }
}

class _YandexLinkDialog extends StatefulWidget {
  const _YandexLinkDialog();

  @override
  State<_YandexLinkDialog> createState() => _YandexLinkDialogState();
}

class _YandexLinkDialogState extends State<_YandexLinkDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isNotEmpty) Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Импорт из Яндекс Диска'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Вставь публичную ссылку на файл или папку. '
            'Закрытые ссылки без публичного доступа не поддерживаются. '
            'Папка импортируется ZIP-архивом до 20 МБ.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            maxLength: 2048,
            decoration: const InputDecoration(
              hintText: 'https://disk.yandex.ru/d/...',
              labelText: 'Ссылка Яндекс Диска',
              prefixIcon: Icon(Icons.link_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Импортировать'),
        ),
      ],
    );
  }
}
