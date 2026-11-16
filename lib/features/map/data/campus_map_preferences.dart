import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CampusMapType { standard, satellite, hybrid, topographic }

extension CampusMapTypeLabel on CampusMapType {
  String get label => switch (this) {
    CampusMapType.standard => 'Обычная',
    CampusMapType.satellite => 'Спутник',
    CampusMapType.hybrid => 'Гибрид',
    CampusMapType.topographic => 'Топографическая',
  };
  String get subtitle => switch (this) {
    CampusMapType.standard => 'Улицы и корпуса',
    CampusMapType.satellite => 'Спутниковые снимки',
    CampusMapType.hybrid => 'Спутник с подписями объектов',
    CampusMapType.topographic => 'Рельеф и топографические объекты',
  };
}

class CampusMapPreferences {
  static const key = 'campus_map_type_v1';
  static final ValueNotifier<CampusMapType> selected =
      ValueNotifier(CampusMapType.standard);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    selected.value = CampusMapType.values.firstWhere(
      (element) => element.name == value,
      orElse: () => CampusMapType.standard,
    );
  }

  static Future<void> setType(CampusMapType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, type.name);
    selected.value = type;
  }
}
