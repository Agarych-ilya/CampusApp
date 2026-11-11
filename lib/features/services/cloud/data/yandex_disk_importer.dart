import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Imports only PUBLIC Yandex Disk share links. No Yandex account/OAuth is
/// required, and no arbitrary user-supplied URL is fetched by Campus backend.
///
/// Shared directories are downloaded as ZIP archives (max 20 MiB).
class YandexDiskImporter {
  YandexDiskImporter({
    http.Client? client,
    Future<Directory> Function()? temporaryDirectory,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final http.Client _client;
  final bool _ownsClient;
  final Future<Directory> Function() _temporaryDirectory;
  static const int maxBytes = 20 * 1024 * 1024;

  static bool _shareHost(String hostname) =>
      {
        'disk.yandex.ru', 'disk.360.yandex.ru',
        'disk.yandex.com', 'disk.yandex.kz', 'disk.yandex.by',
        'yadi.sk',
      }.contains(hostname.toLowerCase());

  static bool _downloadHost(String host) {
    final name = host.toLowerCase();
    return name == 'yandex.ru' || name.endsWith('.yandex.ru') ||
        name == 'yandex.net' || name.endsWith('.yandex.net') ||
        name == 'yandex.com' || name.endsWith('.yandex.com') ||
        name == 'yandex.kz' || name.endsWith('.yandex.kz') ||
        name == 'yandex.by' || name.endsWith('.yandex.by') ||
        name == 'yandexcloud.net' || name.endsWith('.yandexcloud.net') ||
        name == 'yadi.sk';
  }

  static Uri _share(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' ||
        !_shareHost(uri.host) || uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty || uri.path.isEmpty ||
        value.length > 2048) {
      throw const FormatException(
        'Вставь публичную HTTPS-ссылку Яндекс Диска',
      );
    }
    return uri;
  }

  static String _apiError(http.Response response, String operation) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map) {
        final description = value['description']?.toString() ??
            value['message']?.toString() ?? value['error']?.toString();
        if (description != null && description.isNotEmpty) {
          return '$operation: $description (HTTP ${response.statusCode})';
        }
      }
    } catch (_) {}
    if (response.statusCode == 403 || response.statusCode == 401) {
      return '$operation: владелец запретил скачивание или ссылка требует доступа';
    }
    if (response.statusCode == 404) {
      return '$operation: ссылка удалена, закрыта или срок её действия истёк';
    }
    if (response.statusCode == 429) {
      return '$operation: Яндекс ограничил частоту скачиваний; попробуй позже';
    }
    return '$operation: HTTP ${response.statusCode}';
  }

  static String _safeName(String value) {
    final clean = value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final name = clean.trim();
    if (name.isEmpty) return 'Яндекс Диск';
    return name.length > 150 ? name.substring(0, 150) : name;
  }

  Future<YandexImportedFile> download(String link) async {
    final share = _share(link);
    final publicKey = share.toString();
    final metadataUrl = Uri.https('cloud-api.yandex.net',
        '/v1/disk/public/resources', {'public_key': publicKey});
    final metadataResponse = await _client.get(metadataUrl)
        .timeout(const Duration(seconds: 25));
    if (metadataResponse.statusCode != 200) {
      throw Exception(_apiError(metadataResponse, 'Не удалось открыть ссылку'));
    }
    final metadata = jsonDecode(utf8.decode(metadataResponse.bodyBytes));
    if (metadata is! Map) {
      throw const FormatException('Некорректный ответ Яндекс Диска');
    }
    final directory = metadata['type'] == 'dir';
    if (!directory && metadata['type'] != 'file') {
      throw const FormatException('Ресурс Яндекс Диска не поддерживается');
    }
    final size = metadata['size'];
    if (!directory && size is num && size > maxBytes) {
      throw Exception('Файл больше 20 МБ');
    }
    var name = _safeName(metadata['name']?.toString() ?? 'Документ');
    if (directory && !name.toLowerCase().endsWith('.zip')) name += '.zip';

    final downloadApi = Uri.https('cloud-api.yandex.net',
        '/v1/disk/public/resources/download', {'public_key': publicKey});
    final linkResponse = await _client.get(downloadApi)
        .timeout(const Duration(seconds: 25));
    if (linkResponse.statusCode != 200) {
      throw Exception(_apiError(linkResponse,
          'Не удалось получить ссылку для скачивания'));
    }
    final payload = jsonDecode(utf8.decode(linkResponse.bodyBytes));
    if (payload is! Map || payload['href'] is! String) {
      throw const FormatException('Некорректная ссылка скачивания');
    }
    var source = Uri.tryParse(payload['href'] as String);
    if (source == null || source.scheme != 'https' ||
        !_downloadHost(source.host) || source.userInfo.isNotEmpty) {
      throw const FormatException('Небезопасный адрес скачивания');
    }
    final temp = await _temporaryDirectory();
    final output = File(
      '${temp.path}/yandex_import_${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    try {
      for (var redirect = 0; redirect <= 4; redirect++) {
        final request = http.Request('GET', source!);
        request.followRedirects = false;
        final response = await _client.send(request)
            .timeout(const Duration(seconds: 40));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers['location'];
          await response.stream.drain<void>();
          if (location == null) {
            throw const FormatException('Неизвестный адрес перенаправления');
          }
          final next = source.resolve(location);
          if (next.scheme != 'https' || !_downloadHost(next.host) ||
              next.userInfo.isNotEmpty) {
            throw const FormatException('Небезопасное перенаправление');
          }
          source = next;
          continue;
        }
        if (response.statusCode != 200) {
          final bytes = await response.stream.toBytes();
          throw Exception(_apiError(
            http.Response.bytes(bytes.take(8192).toList(),
                response.statusCode),
            'Яндекс не отдал содержимое',
          ));
        }
        if (response.contentLength != null &&
            response.contentLength! > maxBytes) {
          throw Exception('Файл больше 20 МБ');
        }
        final sink = output.openWrite();
        var written = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 40),
          )) {
            written += chunk.length;
            if (written > maxBytes) {
              throw Exception('Файл или ZIP-архив больше 20 МБ');
            }
            sink.add(chunk);
          }
          await sink.flush();
          await sink.close();
        } catch (_) {
          await sink.close();
          rethrow;
        }
        if (written == 0) throw Exception('Яндекс Диск вернул пустой файл');
        return YandexImportedFile(
          file: output,
          name: name,
          directoryArchive: directory,
        );
      }
      throw const FormatException('Слишком много перенаправлений');
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class YandexImportedFile {
  const YandexImportedFile({
    required this.file,
    required this.name,
    required this.directoryArchive,
  });

  final File file;
  final String name;
  final bool directoryArchive;
}
