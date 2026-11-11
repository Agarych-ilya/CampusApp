import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusapp/features/services/cloud/data/yandex_disk_importer.dart';

void main() {
  test('a public Yandex file link downloads real bytes to a temp file', () async {
    final directory = await Directory.systemTemp.createTemp('yandex_import_');
    addTearDown(() => directory.delete(recursive: true));
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      if (request.url.path == '/v1/disk/public/resources') {
        expect(request.url.queryParameters['public_key'],
            'https://disk.yandex.ru/d/example');
        return http.Response(
          '{"type":"file","name":"lecture.txt","size":4}', 200,
        );
      }
      if (request.url.path == '/v1/disk/public/resources/download') {
        return http.Response(
          '{"href":"https://downloader.disk.yandex.ru/file"}', 200,
        );
      }
      expect(request.url.host, 'downloader.disk.yandex.ru');
      return http.Response('DATA', 200);
    });
    final importer = YandexDiskImporter(
      client: client, temporaryDirectory: () async => directory,
    );
    final imported = await importer.download('https://disk.yandex.ru/d/example');
    expect(imported.name, 'lecture.txt');
    expect(imported.directoryArchive, isFalse);
    expect(await imported.file.readAsString(), 'DATA');
    importer.dispose();
    client.close();
  });

  test('a public Yandex folder is imported as a ZIP archive', () async {
    final directory = await Directory.systemTemp.createTemp('yandex_folder_');
    addTearDown(() => directory.delete(recursive: true));
    final importer = YandexDiskImporter(
      client: MockClient((request) async {
        if (request.url.path == '/v1/disk/public/resources') {
          return http.Response('{"type":"dir","name":"ТАУ"}', 200);
        }
        if (request.url.path == '/v1/disk/public/resources/download') {
          return http.Response(
            '{"href":"https://downloader.disk.yandex.ru/zip"}', 200);
        }
        return http.Response('ARCHIVE', 200);
      }),
      temporaryDirectory: () async => directory,
    );
    final archive = await importer.download('https://yadi.sk/d/sample');
    expect(archive.directoryArchive, isTrue);
    expect(archive.name, 'ТАУ.zip');
    expect(await archive.file.readAsString(), 'ARCHIVE');
  });

  test('rejects arbitrary and non-public destination URLs', () async {
    final directory = await Directory.systemTemp.createTemp('yandex_ssrf_');
    addTearDown(() => directory.delete(recursive: true));
    var fetched = false;
    final importer = YandexDiskImporter(
      client: MockClient((request) async {
        fetched = true;
        if (request.url.path == '/v1/disk/public/resources') {
          return http.Response('{"type":"file","name":"test.txt"}', 200);
        }
        if (request.url.path == '/v1/disk/public/resources/download') {
          return http.Response(
            '{"href":"https://127.0.0.1/admin"}', 200);
        }
        return http.Response('SHOULD NOT DOWNLOAD', 200);
      }),
      temporaryDirectory: () async => directory,
    );

    await expectLater(importer.download('https://example.org/private'),
        throwsFormatException);
    expect(fetched, isFalse);
    await expectLater(importer.download('https://disk.yandex.ru/d/test'),
        throwsFormatException);
  });

  test('rejects files larger than the 20MB import limit', () async {
    final client = MockClient((request) async => http.Response(
      '{"type":"file","name":"huge.pdf","size":20971521}', 200,
    ));
    final importer = YandexDiskImporter(client: client);
    await expectLater(
      importer.download('https://disk.yandex.ru/d/huge'),
      throwsException,
    );
    client.close();
  });
}
