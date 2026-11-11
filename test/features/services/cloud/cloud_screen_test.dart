import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _FakeCloudApi extends CloudApi {
  bool saved = false;
  int saves = 0;
  int renames = 0;
  int accessChanges = 0;
  String lastMode = '';
  String lastQuery = '';
  CloudFolder folder = const CloudFolder(
    id: 7,
    name: 'Физика',
    visibility: CloudVisibility.private,
    group: null,
    mine: true,
  );

  CloudFile _file(bool mine, {bool saved = false}) => CloudFile(
        id: mine ? 1 : 2,
        name: mine ? 'Моя лабораторная.pdf' : 'Чужой конспект.pdf',
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
  Future<List<CloudFolder>> getFolders({String mode = 'mine'}) async {
    expect(mode, 'all');
    return [folder];
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
    await tester.pumpWidget(MaterialApp(home: CloudScreen(api: api)));
    await tester.pumpAndSettle();

    expect(api.lastMode, 'search');
    expect(find.text('Все файлы'), findsOneWidget);
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
    await tester.pumpWidget(MaterialApp(home: CloudScreen(api: api)));
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
}
