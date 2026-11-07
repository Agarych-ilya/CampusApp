import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';

/// Public Telegram community description supplied by the Campus backend.
class TelegramGroupData {
  const TelegramGroupData({
    required this.title,
    required this.username,
    required this.subtitle,
  });

  final String title;
  final String username;
  final String subtitle;

  static final RegExp _validUsername = RegExp(r'^[a-zA-Z0-9_]{5,32}$');

  static TelegramGroupData? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final title = value['title'];
    final username = value['username'];
    final subtitle = value['subtitle'];

    if (title is! String ||
        username is! String ||
        subtitle is! String ||
        title.trim().isEmpty ||
        subtitle.trim().isEmpty ||
        !_validUsername.hasMatch(username)) {
      return null;
    }

    return TelegramGroupData(
      title: title.trim(),
      username: username,
      subtitle: subtitle.trim(),
    );
  }
}

class TelegramGroupsApi {
  const TelegramGroupsApi();

  Future<List<TelegramGroupData>> getGroups() async {
    final uri = Uri.parse(ApiConfig.baseUrl + '/services/groups');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 4),
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить группы');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('Некорректный каталог групп');
    }

    final groups = decoded
        .map(TelegramGroupData.tryParse)
        .whereType<TelegramGroupData>()
        .toList();

    if (groups.isEmpty) {
      throw const FormatException('Каталог групп пуст');
    }

    return groups;
  }
}
