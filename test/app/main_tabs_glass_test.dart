import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/app/main_tabs_screen.dart';
import 'package:campusapp/core/theme/app_theme.dart';

void main() {
  testWidgets('navigation is an icon-only glass dock',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const MainTabsScreen(),
    ));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('campus-glass-tab-$i')), findsOneWidget);
    }
    expect(find.byType(BottomNavigationBar), findsNothing);
    final dock = find.byType(BackdropFilter);
    expect(dock, findsOneWidget);
    expect(find.descendant(
      of: dock, matching: find.text('Расписание')), findsNothing);
    expect(find.descendant(
      of: dock, matching: find.text('Сервисы')), findsNothing);
  });
}
