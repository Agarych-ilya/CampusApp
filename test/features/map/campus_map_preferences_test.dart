import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campusapp/features/map/data/campus_map_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('map style survives reopening settings', () async {
    SharedPreferences.setMockInitialValues({});
    await CampusMapPreferences.load();
    expect(CampusMapPreferences.selected.value, CampusMapType.standard);
    await CampusMapPreferences.setType(CampusMapType.hybrid);
    expect(CampusMapPreferences.selected.value, CampusMapType.hybrid);
    CampusMapPreferences.selected.value = CampusMapType.standard;
    await CampusMapPreferences.load();
    expect(CampusMapPreferences.selected.value, CampusMapType.hybrid);
  });

  test('invalid saved style falls back to ordinary map', () async {
    SharedPreferences.setMockInitialValues({
      CampusMapPreferences.key: 'unknown-type',
    });
    await CampusMapPreferences.load();
    expect(CampusMapPreferences.selected.value, CampusMapType.standard);
  });
}
