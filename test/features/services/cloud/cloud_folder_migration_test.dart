import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/data/local_cloud_store.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _MigrationCloudApi extends CloudApi {
  _MigrationCloudApi(this.source, {this.failDownload = false});

  final File source;
  final bool failDownload;
  bool finalized = false;
  int finalizeCalls = 0;

  @override
  Future<List<CloudFile>> getFiles({
    String mode = 'mine', String query = '', int? folderId,
  }) async => [];

  @override
  Future<List<CloudFolder>> getFolders({
    String mode = 'mine', String query = '',
  }) async {
    if (finalized) return [];
    return const [
      CloudFolder(
        id: 7, name: 'Практика', visibility: CloudVisibility.group,
        group: 'А-03-23', mine: true,
      ),
    ];
  }

  @override
  Future<CloudFolderMigration> folderMigrationManifest(int id) async {
    expect(id, 7);
    return const CloudFolderMigration(
      id: 7,
      name: 'Практика',
      files: [
        CloudMigrationItem(
          id: 10, name: 'lecture.txt', size: 6, owned: true,
        ),
      ],
    );
  }

  @override
  Future<File> downloadToTemporary(CloudFile file) async {
    expect(file.id, 10);
    if (failDownload) {
      throw Exception('Соединение прервано до завершения скачивания');
    }
    return source;
  }

  @override
  Future<void> finishFolderMigration(
    int id, List<int> copiedFileIds,
  ) async {
    expect(id, 7);
    expect(copiedFileIds, [10]);
    finalizeCalls++;
    finalized = true;
  }
}

void main() {
  test('local import copies all files and retries without duplicates',
      () async {
    final root = await Directory.systemTemp.createTemp('campus_import_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/lecture.txt');
    await source.writeAsString('notes!');
    final store = LocalCloudStore(rootProvider: () async => root);
    const manifest = CloudFolderMigration(
      id: 7,
      name: 'Практика',
      files: [
        CloudMigrationItem(
          id: 10, name: 'lecture.txt', size: 6, owned: true,
        ),
      ],
    );

    final first = await store.importServerFolder(manifest, {10: source});
    expect(first.local, isTrue);
    final saved = (await store.files(folderId: first.id)).single;
    expect(saved.name, 'lecture.txt');
    expect(await File(saved.localPath!).readAsString(), 'notes!');
    final second = await store.importServerFolder(manifest, {10: source});
    expect(second.id, first.id);
    expect(await store.folders(), hasLength(1));
    expect(await store.files(), hasLength(1));
  });

  test('failed copy does not expose a partially imported folder', () async {
    final root = await Directory.systemTemp.createTemp('campus_fail_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/a.txt');
    await source.writeAsString('hello');
    final store = LocalCloudStore(rootProvider: () async => root);
    const manifest = CloudFolderMigration(
      id: 7,
      name: 'Практика',
      files: [
        CloudMigrationItem(id: 10, name: 'a.txt', size: 5, owned: true),
        CloudMigrationItem(id: 11, name: 'b.txt', size: 5, owned: true),
      ],
    );
    await expectLater(
      store.importServerFolder(manifest, {10: source}),
      throwsFormatException,
    );
    expect(await store.folders(), isEmpty);
    expect(await store.files(), isEmpty);
  });

  testWidgets('making a shared folder private copies before finalization',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = await Directory.systemTemp.createTemp('campus_screen_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/source.txt');
    await source.writeAsString('notes!');
    final store = LocalCloudStore(rootProvider: () async => root);
    final api = _MigrationCloudApi(source);

    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настроить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настроить доступ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Личное').last);
    await tester.pumpAndSettle();
    expect(find.text('Сделать папку личной?'), findsOneWidget);
    expect(api.finalizeCalls, 0);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(api.finalized, isTrue);
    expect(api.finalizeCalls, 1);
    final local = (await store.folders()).single;
    expect(local.local, isTrue);
    expect((await store.files(folderId: local.id)).single.name, 'lecture.txt');
    expect(tester.takeException(), isNull);
  });

  testWidgets('download failure leaves server folder and links untouched',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = await Directory.systemTemp.createTemp('campus_fail_ui_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/source.txt');
    await source.writeAsString('notes!');
    final store = LocalCloudStore(rootProvider: () async => root);
    final api = _MigrationCloudApi(source, failDownload: true);

    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настроить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настроить доступ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Личное').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(api.finalizeCalls, 0);
    expect((await store.folders()), isEmpty);
    expect(find.text('Практика'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
