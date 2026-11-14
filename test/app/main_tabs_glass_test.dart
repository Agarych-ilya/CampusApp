import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/app/main_tabs_screen.dart';
import 'package:campusapp/core/theme/app_theme.dart';

void main() {
  testWidgets('glass navigation shows five interactive icons without captions',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    int? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        bottomNavigationBar: CampusGlassDock(
          currentIndex: 0,
          onSelected: (i) => picked = i,
        ),
      ),
    ));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('campus-glass-tab-$i')), findsOneWidget);
    }
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Расписание'), findsNothing);
    expect(find.text('Профиль'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('campus-glass-tab-3')));
    expect(picked, 3);
  });
}
