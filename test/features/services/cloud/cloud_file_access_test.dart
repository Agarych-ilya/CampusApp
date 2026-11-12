import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/data/local_cloud_store.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _FileTransferApi extends CloudApi {
  _FileTransferApi(this.root);
  final Directory root;
  final files = <CloudFile>[];
  final sourceById = <int, File>{};
  int nextId = 100;
  int uploads = 0;
  bool corruptDownload = false;

  @override
  Future<List<CloudFolder>> getFolders({
    String mode = 'mine', String query = '',
  }) async => [];

  @override
  Future<List<CloudFile>> getFiles({
    String mode = 'mine', String query = '', int? folderId,
  }) async => [
    for (final file in files)
      if (file.name.toLowerCase().contains(query.toLowerCase()))
        file,
  ];

  @override
  Future<CloudQuota> getQuota() async => const CloudQuota(
    usedBytes: 0, usedFiles: 0, usedFolders: 0,
    maxFileBytes: 20 * 1024 * 1024,
    maxImageBytes: 5 * 1024 * 1024,
    maxStorageBytes: 500 * 1024 * 1024,
    maxFiles: 500, maxFolders: 100,
  );

  @override
  Future<int> uploadFileReturningId(String path, {
    int? folderId,
    CloudVisibility visibility = CloudVisibility.private,
    String? filename,
  }) async {
    expect(folderId, isNull);
    expect(visibility, CloudVisibility.private);
    final id = nextId++;
    final saved = await File(path).copy('${root.path}/server_$id.dat');
    sourceById[id] = saved;
    files.add(CloudFile(
      id: id, name: filename!,
      size: await saved.length(),
      mime: 'text/plain', folderId: null,
      visibility: CloudVisibility.private,
      group: null, mine: true, saved: false, image: false,
      available: true,
    ));
    uploads++;
    return id;
  }

  @override
  Future<File> downloadToTemporary(CloudFile file) async {
    final temp = File(
      '${root.path}/verify_${file.id}_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (corruptDownload) {
      await temp.writeAsString('different file data');
      return temp;
    }
    return sourceById[file.id]!.copy(temp.path);
  }

  @override
  Future<void> changeVisibility(
      int id, CloudVisibility visibility) async {
    final index = files.indexWhere((item) => item.id == id);
    expect(index, greaterThanOrEqualTo(0));
    final previous = files[index];
    files[index] = CloudFile(
      id: id, name: previous.name, size: previous.size,
      mime: previous.mime, folderId: null,
      visibility: visibility, group: null, mine: true,
      saved: false, image: false, available: true,
    );
  }
}

Future<void> _selectPublic(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Действия с файлом').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Настроить доступ').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Всем').last);
  await tester.pumpAndSettle();
  expect(find.text('Изменить доступ к файлу?'), findsOneWidget);
  await tester.tap(find.text('Продолжить'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('private Russian-named file becomes one public file, no duplicate',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = await Directory.systemTemp.createTemp('campus_single_move_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    final original = File('${root.path}/original.txt');
    await original.writeAsString('Материалы по ТАУ');
    await store.saveFile(original.path, name: 'Лабораторная МЭИ.txt');
    final api = _FileTransferApi(root);

    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Лабораторная МЭИ.txt'), findsOneWidget);
    await _selectPublic(tester);

    expect(api.uploads, 1);
    expect(api.files.single.visibility, CloudVisibility.public);
    expect(api.files.single.name, 'Лабораторная МЭИ.txt');
    expect(await store.files(), isEmpty);
    expect(find.text('Лабораторная МЭИ.txt'), findsOneWidget);
    expect(find.text('На устройстве'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network verification failure keeps local original and retries '
      'without uploading a duplicate', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = await Directory.systemTemp.createTemp('campus_retry_file_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    final original = File('${root.path}/original.txt');
    await original.writeAsString('contents');
    await store.saveFile(original.path, name: 'Конспект.txt');
    final api = _FileTransferApi(root)..corruptDownload = true;
    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();

    await _selectPublic(tester);
    expect(await store.files(), hasLength(1));
    expect(api.files.single.visibility, CloudVisibility.private);
    expect(api.uploads, 1);
    expect(find.text('Конспект.txt'), findsOneWidget);

    api.corruptDownload = false;
    await _selectPublic(tester);
    expect(api.uploads, 1);
    expect(await store.files(), isEmpty);
    expect(api.files.single.visibility, CloudVisibility.public);
    expect(find.text('Конспект.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
