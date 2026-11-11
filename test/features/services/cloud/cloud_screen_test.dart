import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _FakeCloudApi extends CloudApi {
  bool saved = false;
  int saves = 0;
  String lastMode = '';

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
    final my = _file(true);
    final shared = _file(false, saved: saved);
    if (query.trim().isNotEmpty) {
      return [my, shared].where((file) =>
          file.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
    if (mode == 'mine') return [my, if (saved) shared];
    return [shared];
  }

  @override
  Future<List<CloudFolder>> getFolders({String mode = 'mine'}) async => [];

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

  testWidgets('found shared file can be saved and appears in My files',
      (tester) async {
    final api = _FakeCloudApi();
    await tester.pumpWidget(MaterialApp(
      home: CloudScreen(api: api),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Моя лабораторная.pdf'), findsOneWidget);
    expect(find.text('Чужой конспект.pdf'), findsNothing);
    await tester.tap(find.text('Общее'));
    await tester.pumpAndSettle();
    expect(find.text('Чужой конспект.pdf'), findsOneWidget);
    expect(find.text('Сохранить себе'), findsOneWidget);
    await tester.tap(find.text('Сохранить себе'));
    await tester.pumpAndSettle();
    expect(api.saves, 1);
    expect(find.text('Сохранено у меня'), findsOneWidget);

    await tester.tap(find.text('Мои файлы'));
    await tester.pumpAndSettle();
    expect(api.lastMode, 'mine');
    expect(find.text('Чужой конспект.pdf'), findsOneWidget);
  });
}
