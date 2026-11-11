import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/data/local_cloud_store.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _PublishApi extends CloudApi {
  _PublishApi(this.root);

  final Directory root;
  CloudFolder? published;
  final List<CloudFile> remote = [];
  final Map<int, File> remoteContent = {};
  bool failUpload = false;
  int createdFolders = 0;
  int uploads = 0;
  int nextId = 55;

  @override
  Future<List<CloudFolder>> getFolders({
    String mode = 'mine', String query = '',
  }) async => [
    if (published != null && published!.name.contains(query)) published!,
  ];

  @override
  Future<List<CloudFile>> getFiles({
    String mode = 'mine', String query = '', int? folderId,
  }) async {
    if (folderId != null && folderId == published?.id) {
      return remote.where((file) => file.name.contains(query)).toList();
    }
    return [];
  }

  @override
  Future<CloudFolder> createFolder(
      String name, CloudVisibility visibility) async {
    createdFolders++;
    expect(visibility, CloudVisibility.private);
    published = CloudFolder(
      id: 44, name: name, visibility: visibility, group: null, mine: true,
    );
    return published!;
  }

  @override
  Future<void> uploadFile(String path, {
    int? folderId,
    CloudVisibility visibility = CloudVisibility.private,
    String? filename,
  }) async {
    if (failUpload) throw Exception('Нет соединения во время загрузки');
    expect(folderId, published?.id);
    expect(visibility, CloudVisibility.private);
    final id = nextId++;
    final copy = await File(path).copy('${root.path}/server_$id.dat');
    remoteContent[id] = copy;
    remote.add(CloudFile(
      id: id, name: filename ?? 'no-name', available: true,
      size: await copy.length(), mime: 'text/plain',
      folderId: folderId, visibility: visibility, group: null,
      mine: true, saved: false, image: false,
    ));
    uploads++;
  }

  @override
  Future<File> downloadToTemporary(CloudFile file) async {
    final content = remoteContent[file.id]!;
    return content.copy(
      '${root.path}/verified_${file.id}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  @override
  Future<CloudFolder> changeFolderVisibility(
      int id, CloudVisibility visibility) async {
    expect(id, published?.id);
    published = CloudFolder(
      id: id, name: published!.name, visibility: visibility,
      group: visibility == CloudVisibility.group ? 'А-03-23' : null,
      mine: true,
    );
    return published!;
  }

  Future<void> seedOldPublishedCopy(
      String name, File source, String fileName) async {
    published = CloudFolder(
      id: 44, name: name, visibility: CloudVisibility.public,
      group: null, mine: true,
    );
    const id = 54;
    final copy = await source.copy('${root.path}/existing_$id.dat');
    remoteContent[id] = copy;
    remote.add(CloudFile(
      id: id, name: fileName, available: true,
      size: await copy.length(), mime: 'text/plain',
      folderId: published!.id, visibility: CloudVisibility.public,
      group: null, mine: true, saved: false, image: false,
    ));
  }
}

Future<({LocalCloudStore store, CloudFolder folder, File original})>
    _setupPrivate(Directory root) async {
  final store = LocalCloudStore(rootProvider: () async => root);
  final folder = await store.createFolder('UBS');
  final source = File('${root.path}/original.txt');
  await source.writeAsString('lecture notes');
  await store.saveFile(
    source.path, name: 'notes.txt', folderId: folder.id,
  );
  return (store: store, folder: folder, original: source);
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _switchToPublic(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Настроить папку').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Настроить доступ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Всем').last);
  await tester.pumpAndSettle();
  expect(find.text('Перенести папку в облако?'), findsOneWidget);
  await tester.tap(find.text('Продолжить'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('private to public MOVE leaves exactly one folder in All Files',
      (tester) async {
    await _setViewport(tester);
    final root = await Directory.systemTemp.createTemp('publish_one_');
    addTearDown(() => root.delete(recursive: true));
    final fixture = await _setupPrivate(root);
    final api = _PublishApi(root);
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api, localStore: fixture.store,
    )));
    await tester.pumpAndSettle();
    expect(find.text('UBS'), findsOneWidget);

    await _switchToPublic(tester);
    expect(api.createdFolders, 1);
    expect(api.uploads, 1);
    expect(api.published?.visibility, CloudVisibility.public);
    expect(await fixture.store.folders(), isEmpty);
    expect(find.text('UBS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed upload keeps one visible local folder and retries',
      (tester) async {
    await _setViewport(tester);
    final root = await Directory.systemTemp.createTemp('publish_retry_');
    addTearDown(() => root.delete(recursive: true));
    final fixture = await _setupPrivate(root);
    final api = _PublishApi(root)..failUpload = true;
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api, localStore: fixture.store,
    )));
    await tester.pumpAndSettle();

    await _switchToPublic(tester);
    expect(await fixture.store.folders(), hasLength(1));
    expect(api.createdFolders, 1);
    expect(api.published?.visibility, CloudVisibility.private);
    // The private staging folder is hidden; the personal copy is visible.
    expect(find.text('UBS'), findsOneWidget);

    api.failUpload = false;
    await _switchToPublic(tester);
    expect(api.createdFolders, 1); // no second server copy
    expect(await fixture.store.folders(), isEmpty);
    expect(api.published?.visibility, CloudVisibility.public);
    expect(find.text('UBS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy duplicate UBS folders can be merged after byte check',
      (tester) async {
    await _setViewport(tester);
    final root = await Directory.systemTemp.createTemp('publish_legacy_');
    addTearDown(() => root.delete(recursive: true));
    final fixture = await _setupPrivate(root);
    final api = _PublishApi(root);
    await api.seedOldPublishedCopy(
      'UBS', fixture.original, 'notes.txt',
    );
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api, localStore: fixture.store,
    )));
    await tester.pumpAndSettle();
    expect(find.text('UBS'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Настроить папку').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Объединить с облачной копией'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(api.createdFolders, 0);
    expect(api.uploads, 0);
    expect(await fixture.store.folders(), isEmpty);
    expect(find.text('UBS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('different content in legacy copies is never removed',
      (tester) async {
    await _setViewport(tester);
    final root = await Directory.systemTemp.createTemp('publish_diff_');
    addTearDown(() => root.delete(recursive: true));
    final fixture = await _setupPrivate(root);
    final other = File('${root.path}/other.txt');
    await other.writeAsString('changed note!'); // same size, different bytes
    final api = _PublishApi(root);
    await api.seedOldPublishedCopy('UBS', other, 'notes.txt');
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api, localStore: fixture.store,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настроить папку').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Объединить с облачной копией'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(await fixture.store.folders(), hasLength(1));
    expect(find.text('UBS'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
