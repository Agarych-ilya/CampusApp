import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/data/local_cloud_store.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _FakeCloudApi extends CloudApi {
  bool saved = false;
  int saves = 0;
  int renames = 0;
  int accessChanges = 0;
  String lastMode = '';
  String lastQuery = '';
  String folderQuery = '';
  int uploads = 0;
  int fileRenames = 0;
  int folderLinks = 0;
  String myFileName = 'Моя лабораторная.pdf';
  CloudFolder folder = const CloudFolder(
    id: 7,
    name: 'Физика',
    visibility: CloudVisibility.private,
    group: null,
    mine: true,
  );

  CloudFile _file(bool mine, {bool saved = false}) => CloudFile(
        id: mine ? 1 : 2,
        name: mine ? myFileName : 'Чужой конспект.pdf',
        available: true,
        size: 30720,
        mime: 'application/pdf',
        folderId: null,
        visibility: mine
            ? CloudVisibility.private
            : CloudVisibility.group,
        group: mine ? null : 'А-03-23',
        mine: mine,
        saved: saved,
        image: false,
      );

  @override
  Future<List<CloudFile>> getFiles({
    String mode = 'mine',
    String query = '',
    int? folderId,
  }) async {
    lastMode = mode;
    lastQuery = query;
    final all = [_file(true), _file(false, saved: saved)];
    if (folderId != null) return [];
    if (mode != 'search') {
      throw StateError('Cloud Campus must use one unified catalogue');
    }
    if (query.trim().isNotEmpty) {
      return all.where((file) =>
          file.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
    return all;
  }

  @override
  Future<List<CloudFolder>> getFolders({
    String mode = 'mine',
    String query = '',
  }) async {
    expect(mode, 'all');
    folderQuery = query;
    return folder.name.toLowerCase().contains(query.toLowerCase())
        ? [folder] : [];
  }

  @override
  Future<void> uploadFile(
    String path, {
    int? folderId,
    CloudVisibility visibility = CloudVisibility.private,
    String? filename,
  }) async {
    uploads++;
  }

  @override
  Future<CloudFolder> renameFolder(int id, String name) async {
    expect(id, folder.id);
    renames++;
    folder = CloudFolder(
      id: folder.id, name: name, visibility: folder.visibility,
      group: folder.group, mine: true,
    );
    return folder;
  }

  @override
  Future<CloudFolder> changeFolderVisibility(
    int id, CloudVisibility visibility,
  ) async {
    expect(id, folder.id);
    accessChanges++;
    folder = CloudFolder(
      id: folder.id, name: folder.name, visibility: visibility,
      group: visibility == CloudVisibility.group ? 'А-03-23' : null,
      mine: true,
    );
    return folder;
  }

  @override
  Future<void> renameFile(int id, String name) async {
    expect(id, 1);
    fileRenames++;
    myFileName = name;
  }

  @override
  Future<Uri> createFolderShareLink(int id) async {
    expect(id, folder.id);
    folderLinks++;
    return Uri.parse('https://campus.example/cloud/f/testtoken');
  }

  @override
  Future<void> revokeFolderShareLink(int id) async {
    expect(id, folder.id);
  }

  @override
  Future<void> saveFile(int id, {int? folderId}) async {
    expect(id, 2);
    saved = true;
    saves++;
  }

  @override
  Future<void> unsaveFile(int id) async {
    expect(id, 2);
    saved = false;
  }
}

void main() {
  test('Cloud storage quota is 500 MB and progress matches used bytes', () {
    final quota = CloudQuota.fromJson({
      'usedBytes': 125 * 1024 * 1024,
      'usedFiles': 12,
      'usedFolders': 3,
      'limits': {
        'fileBytes': 20 * 1024 * 1024,
        'imageBytes': 5 * 1024 * 1024,
        'totalBytes': 500 * 1024 * 1024,
        'files': 500,
        'folders': 100,
      },
    });
    expect(quota.maxStorageBytes, 500 * 1024 * 1024);
    expect(quota.usedFraction, 0.25);
    expect(() => quota.validateUpload(21 * 1024 * 1024, image: false),
        throwsException);
    expect(() => quota.validateUpload(6 * 1024 * 1024, image: true),
        throwsException);
  });

  test('CloudFile decodes access scope, thumbnail and saved flags', () {
    final file = CloudFile.fromJson({
      'id': 12,
      'name': 'Фото.png',
      'mime': 'image/png',
      'image': true,
      'size': 1248,
      'available': true,
      'visibility': 'group',
      'group': 'А-03-23',
      'mine': false,
      'saved': true,
      'folderId': null,
    });
    expect(file.image, isTrue);
    expect(file.visibility, CloudVisibility.group);
    expect(file.saved, isTrue);
    expect(file.mine, isFalse);
  });

  testWidgets('one catalogue shows all accessible files and saves a shared file',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeCloudApi();
    final root = await Directory.systemTemp.createTemp('campus_cloud_test_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();

    expect(api.lastMode, 'search');
    expect(find.text('Папки'), findsOneWidget);
    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('Мои файлы'), findsNothing);
    expect(find.text('Общее'), findsNothing);
    expect(find.text('Моя лабораторная.pdf'), findsOneWidget);
    expect(find.text('Чужой конспект.pdf'), findsOneWidget);

    await tester.tap(find.text('Сохранить себе'));
    await tester.pumpAndSettle();
    expect(api.saves, 1);
    expect(find.text('Сохранено у меня'), findsOneWidget);
    expect(find.text('Чужой конспект.pdf'), findsOneWidget);

    // The same search box filters across both own and shared materials.
    await tester.enterText(find.byType(TextField), 'Чужой');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.lastQuery, 'Чужой');
    expect(api.lastMode, 'search');
    expect(find.text('Чужой конспект.pdf'), findsOneWidget);
    expect(find.text('Моя лабораторная.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folder menu has separate name and access actions',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeCloudApi();
    final root = await Directory.systemTemp.createTemp('campus_cloud_test_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настроить папку'));
    await tester.pumpAndSettle();
    expect(find.text('Переименовать'), findsOneWidget);
    expect(find.text('Настроить доступ'), findsOneWidget);
    expect(find.text('Название и доступ'), findsNothing);

    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Физика 2');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(api.renames, 1);
    expect(api.accessChanges, 0);
    expect(find.text('Физика 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Настроить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настроить доступ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Моя группа').last);
    await tester.pumpAndSettle();
    expect(api.renames, 1);
    expect(api.accessChanges, 1);
    expect(api.folder.name, 'Физика 2');
    expect(api.folder.visibility, CloudVisibility.group);
    expect(tester.takeException(), isNull);
  });
  testWidgets('search matches folder names and shows the folder result',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeCloudApi();
    final root = await Directory.systemTemp.createTemp('campus_cloud_folder_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Физика');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.folderQuery, 'Физика');
    expect(find.text('Папки'), findsOneWidget);
    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('Физика'), findsOneWidget);
    expect(find.text('Чужой конспект.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('private files and folders stay entirely in local storage', () async {
    final root = await Directory.systemTemp.createTemp('campus_private_test_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/source.txt');
    await source.writeAsString('Университетская лабораторная');
    final local = LocalCloudStore(rootProvider: () async => root);
    final folder = await local.createFolder('Мои заметки');
    expect(folder.local, isTrue);
    expect(folder.id, lessThan(0));
    final stored = await local.saveFile(
      source.path, name: 'Секрет.txt', folderId: folder.id,
    );
    expect(stored.local, isTrue);
    expect(stored.localPath, isNot(source.path));
    expect(await File(stored.localPath!).readAsString(),
        'Университетская лабораторная');
    expect((await local.files(query: 'секрет')).single.name, 'Секрет.txt');
    expect((await local.folders(query: 'заметки')).single.name, 'Мои заметки');
    expect(await local.files(rootOnly: true), isEmpty);
    expect((await local.files(folderId: folder.id)).single.id, stored.id);
    await local.renameFile(stored.id, 'Лабораторная.txt');
    expect((await local.files()).single.name, 'Лабораторная.txt');
    await expectLater(local.renameFile(stored.id, 'fake.pdf'),
        throwsFormatException);

    // Local metadata and bytes survive re-creation of the store object.
    final reopened = LocalCloudStore(rootProvider: () async => root);
    expect((await reopened.files()).single.local, isTrue);
    await reopened.deleteFile(stored);
    expect(await File(stored.localPath!).exists(), isFalse);
    await reopened.deleteFolder(folder.id);
    expect(await reopened.folders(), isEmpty);
  });

  testWidgets('owners can rename a file without changing its storage',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeCloudApi();
    final root = await Directory.systemTemp.createTemp('campus_file_rename_');
    addTearDown(() => root.delete(recursive: true));
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api,
      localStore: LocalCloudStore(rootProvider: () async => root),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с файлом').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Лекция.pdf');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(api.fileRenames, 1);
    expect(find.text('Лекция.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local-only files and matching local folders are searchable',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = await Directory.systemTemp.createTemp('campus_ui_local_');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalCloudStore(rootProvider: () async => root);
    final folder = await store.createFolder('Секретная папка');
    final source = File('${root.path}/private.txt');
    await source.writeAsString('only local bytes');
    await store.saveFile(source.path,
        name: 'личный конспект.txt', folderId: folder.id);
    final api = _FakeCloudApi();

    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api, localStore: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Секретная папка'), findsOneWidget);
    expect(find.text('личный конспект.txt'), findsOneWidget);
    expect(find.text('Личное'), findsWidgets);
    expect(find.text('На устройстве'), findsNothing);
    expect(api.uploads, 0);

    await tester.enterText(find.byType(TextField).first, 'секретная');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Секретная папка'), findsOneWidget);
    expect(find.text('личный конспект.txt'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(api.uploads, 0);
  });

}
