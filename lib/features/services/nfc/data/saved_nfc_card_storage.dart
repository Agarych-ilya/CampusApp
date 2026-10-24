import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local record of an NFC tag, NOT an access credential.
/// No protected sectors or authentication keys are read or stored.
class SavedNfcCard {
  const SavedNfcCard({
    required this.identifier,
    required this.technology,
    required this.savedAt,
  });

  /// Identifier reported by the OS; not an access key, and some cards rotate it.
  final String identifier;
  final String technology;
  final DateTime savedAt;

  String get displayIdentifier {
    if (identifier.isEmpty) return 'Недоступен';
    final suffix = identifier.length > 4
        ? identifier.substring(identifier.length - 4)
        : identifier;
    return '•••• ' + suffix;
  }

  String get formattedDate {
    final local = savedAt.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    return pad(local.day) + '.' + pad(local.month) + '.' +
        local.year.toString() + ' ' + pad(local.hour) + ':' +
        pad(local.minute);
  }

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'technology': technology,
    'savedAt': savedAt.toIso8601String(),
  };

  static SavedNfcCard? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['identifier'];
    final technology = value['technology'];
    final stamp = value['savedAt'];
    final date = stamp is String ? DateTime.tryParse(stamp) : null;

    if (id is! String || technology is! String || date == null) {
      return null;
    }

    return SavedNfcCard(
      identifier: id,
      technology: technology,
      savedAt: date,
    );
  }
}

class SavedNfcCardStorage {
  static const _key = 'campus_saved_nfc_card_v1';

  Future<SavedNfcCard?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;

    try {
      return SavedNfcCard.fromJson(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedNfcCard card) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setString(_key, jsonEncode(card.toJson()));
    if (!success) throw StateError('Не удалось сохранить NFC-карту');
  }

  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.remove(_key);
    if (!success) throw StateError('Не удалось удалить NFC-карту');
  }
}
