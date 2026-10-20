import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A personal avatar stored only on this device.
class ProfileAvatarStorage {
  static const _key = 'campus_profile_avatar_path';
  static const _maxBytes = 15 * 1024 * 1024;

  Future<File?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);

    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (await file.exists()) return file;

    await prefs.remove(_key);
    return null;
  }

  /// Returns null when the user closes the file picker.
  Future<File?> pickAndSaveAvatar() async {
    final selection = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (selection == null) return null;

    final size = selection.lengthSync() ?? await selection.length();
    if (size > _maxBytes) {
      throw const FileSystemException(
        'Выбери фотографию размером не более 15 МБ',
      );
    }

    final originalPath = selection.path;
    if (originalPath == null || originalPath.isEmpty) {
      throw const FileSystemException('Не удалось прочитать выбранное фото');
    }

    final original = File(originalPath);
    if (!await original.exists()) {
      throw const FileSystemException('Выбранная фотография недоступна');
    }

    final folder = await _directory();
    await folder.create(recursive: true);

    final extension = _extension(selection.extension);
    final target = File(
      '${folder.path}${Platform.pathSeparator}'
      'avatar_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );

    await original.copy(target.path);

    final previous = await getAvatar();
    final prefs = await SharedPreferences.getInstance();

    try {
      final saved = await prefs.setString(_key, target.path);
      if (!saved) throw const FileSystemException('Не удалось сохранить фото');
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }

    // Replacing a picture must not delete arbitrary user files.
    await _deleteManaged(previous);
    return target;
  }

  Future<void> clearAvatar() async {
    final previous = await getAvatar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _deleteManaged(previous);
  }

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}profile_avatar',
    );
  }

  String _extension(String? value) {
    switch (value?.toLowerCase()) {
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'heic':
        return 'heic';
      case 'heif':
        return 'heif';
      default:
        return 'jpg';
    }
  }

  Future<void> _deleteManaged(File? file) async {
    if (file == null) return;
    final folder = await _directory();
    final prefix = '${folder.path}${Platform.pathSeparator}avatar_';

    if (!file.path.startsWith(prefix)) return;

    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The new avatar remains saved even if removal of the old one fails.
    }
  }
}
