import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/cloud/data/cloud_api.dart';
import 'package:campusapp/features/services/cloud/data/local_cloud_store.dart';
import 'package:campusapp/features/services/cloud/view/cloud_screen.dart';

class _BatchCloudApi extends CloudApi {
  final uploaded = <String>[];
  String? failFor;

  @override
  Future<CloudQuota> getQuota() async => const CloudQuota(
        usedBytes: 125 * 1024 * 1024,
        usedFiles: 2,
        usedFolders: 1,
        maxFileBytes: 20 * 1024 * 1024,
        maxImageBytes: 5 * 1024 * 1024,
        maxStorageBytes: 500 * 1024 * 1024,
        maxFiles: 500,
        maxFolders: 100,
      );

  @override
  Future<List<CloudFolder>> getFolders({
    String mode = 'mine', String query = '',
  }) async => [];

  @override
  Future<List<CloudFile>> getFiles({
    String mode = 'mine', String query = '', int? folderId,
  }) async => [];

  @override
  Future<void> uploadFile(String path, {
    int? folderId,
    CloudVisibility visibility = CloudVisibility.private,
    String? filename,
  }) async {
    expect(visibility, CloudVisibility.public);
    if (filename == failFor) throw Exception('Ошибка соединения');
    uploaded.add(filename ?? '');
  }
}

Future<void> _openMultiPicker(WidgetTester tester) async {
  await tester.tap(find.text('Создать'));
  await tester.pumpAndSettle();
  expect(find.text('Добавить файлы'), findsOneWidget);
  await tester.tap(find.text('Добавить файлы'));
  await tester.pumpAndSettle();
}

Future<void> _setScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<List<CloudPickedFile>> _createTwoFiles(Directory directory) async {
  final one = File('${directory.path}/a.txt');
  final two = File('${directory.path}/b.txt');
  await one.writeAsString('first');
  await two.writeAsString('second');
  return [
    CloudPickedFile(path: one.path, name: 'a.txt'),
    CloudPickedFile(path: two.path, name: 'b.txt'),
  ];
}

void main() {
  test('batch preflight checks total bytes and file count', () {
    const lowSpace = CloudQuota(
      usedBytes: 499 * 1024 * 1024,
      usedFiles: 10,
      usedFolders: 1,
      maxFileBytes: 20 * 1024 * 1024,
      maxImageBytes: 5 * 1024 * 1024,
      maxStorageBytes: 500 * 1024 * 1024,
      maxFiles: 500,
      maxFolders: 100,
    );
    expect(() => lowSpace.validateBatch([
      (size: 1024 * 1024, image: false),
      (size: 1024 * 1024, image: false),
    ]), throwsException);

    const almostFull = CloudQuota(
      usedBytes: 0, usedFiles: 499, usedFolders: 1,
      maxFileBytes: 20 * 1024 * 1024,
      maxImageBytes: 5 * 1024 * 1024,
      maxStorageBytes: 500 * 1024 * 1024,
      maxFiles: 500, maxFolders: 100,
    );
    expect(() => almostFull.validateBatch([
      (size: 4, image: false),
      (size: 4, image: false),
    ]), throwsException);
  });

  testWidgets('storage bar has bold used/free numbers and 14px height',
      (tester) async {
    await _setScreen(tester);
    final api = _BatchCloudApi();
    final root = await Directory.systemTemp.createTemp('cloud_bar_');
    addTearDown(() => root.delete(recursive: true));
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api,
      localStore: LocalCloudStore(rootProvider: () async => root),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Занято'), findsOneWidget);
    expect(find.text('Осталось'), findsOneWidget);
    expect(find.text('125 МБ'), findsOneWidget);
    expect(find.text('375 МБ'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('cloud-usage-bar')),
    );
    expect(progress.value, 0.25);
    expect(progress.minHeight, 14);
    final used = tester.widget<Text>(
      find.byKey(const ValueKey('cloud-used')),
    );
    final remaining = tester.widget<Text>(
      find.byKey(const ValueKey('cloud-remaining')),
    );
    expect(used.style?.color, Colors.redAccent);
    expect(used.style?.fontSize, 17);
    expect(remaining.style?.fontSize, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two selected files are uploaded with one visibility choice',
      (tester) async {
    await _setScreen(tester);
    final api = _BatchCloudApi();
    final root = await Directory.systemTemp.createTemp('cloud_upload_');
    addTearDown(() => root.delete(recursive: true));
    final picked = await _createTwoFiles(root);
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api,
      localStore: LocalCloudStore(rootProvider: () async => root),
      pickFiles: () async => picked,
    )));
    await tester.pumpAndSettle();
    await _openMultiPicker(tester);
    await tester.tap(find.text('Всем').last);
    await tester.pumpAndSettle();

    expect(api.uploaded, ['a.txt', 'b.txt']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two personal files are stored locally without cloud uploads',
      (tester) async {
    await _setScreen(tester);
    final api = _BatchCloudApi();
    final root = await Directory.systemTemp.createTemp('cloud_local_');
    addTearDown(() => root.delete(recursive: true));
    final local = LocalCloudStore(rootProvider: () async => root);
    final picked = await _createTwoFiles(root);
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api, localStore: local,
      pickFiles: () async => picked,
    )));
    await tester.pumpAndSettle();
    await _openMultiPicker(tester);
    await tester.tap(find.text('Личное').last);
    await tester.pumpAndSettle();

    expect(api.uploaded, isEmpty);
    expect(await local.files(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch stops on first error and shows partial result',
      (tester) async {
    await _setScreen(tester);
    final api = _BatchCloudApi()..failFor = 'b.txt';
    final root = await Directory.systemTemp.createTemp('cloud_error_');
    addTearDown(() => root.delete(recursive: true));
    final picked = await _createTwoFiles(root);
    await tester.pumpWidget(MaterialApp(home: CloudScreen(
      api: api,
      localStore: LocalCloudStore(rootProvider: () async => root),
      pickFiles: () async => picked,
    )));
    await tester.pumpAndSettle();
    await _openMultiPicker(tester);
    await tester.tap(find.text('Всем').last);
    await tester.pumpAndSettle();

    expect(api.uploaded, ['a.txt']);
    expect(find.textContaining('Добавлено 1 из 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
