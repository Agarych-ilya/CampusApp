import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:campusapp/features/map/view/campus_marker_editor.dart';
import 'package:campusapp/features/map/data/campus_map_api.dart';

void main() {
  testWidgets('saving a map marker keeps controllers alive through dialog exit',
      (tester) async {
    CampusMapDraft? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => FilledButton(
          onPressed: () async {
            saved = await showCampusMarkerEditor(
              context, const LatLng(55.7557, 37.7088),
            );
          },
          child: const Text('Открыть редактор'),
        )),
      ),
    ));
    await tester.tap(find.text('Открыть редактор'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить метку'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'), 'Корпус М',
    );
    await tester.tap(find.text('Сохранить'));
    // showDialog completes when pop begins; the text widgets still animate out.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(saved?.name, 'Корпус М');
    expect(saved?.latitude, 55.7557);
    expect(saved?.longitude, 37.7088);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling the map editor releases the route safely',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => FilledButton(
          onPressed: () => showCampusMarkerEditor(
            context, const LatLng(55.7557, 37.7088),
          ),
          child: const Text('Редактировать карту'),
        )),
      ),
    ));
    await tester.tap(find.text('Редактировать карту'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить метку'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
