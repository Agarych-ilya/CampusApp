import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '/core/config/api_config.dart';

const communityCategories = <String>[
  'Студенческие чаты',
  'Первокурсникам',
  'Новости и мемы',
  'Новости университета',
  'Клубы и интересы',
  'Учёба',
  'Мероприятия',
  'Другое',
];

const communityIconKinds = <String>[
  'chat',
  'campus',
  'news',
  'study',
  'club',
  'events',
];

class CommunityData {
  const CommunityData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.iconKind,
    this.memberCount,
    this.memberCountSource,
    this.memberCountCheckedAt,
    this.memberCountApproximate = false,
    this.iconUrl,
    this.localIconPath,
    this.telegramUrl,
    this.vkUrl,
    this.isPending = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String category;
  final String iconKind;
  final int? memberCount;
  final String? memberCountSource;
  final String? memberCountCheckedAt;
  final bool memberCountApproximate;
  final String? iconUrl;
  final String? localIconPath;
  final String? telegramUrl;
  final String? vkUrl;
  final bool isPending;

  String get membersLabel {
    final count = memberCount;
    if (count == null) return 'Нет данных об участниках';
    final formatted = count.toString().replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+$)'),
      (_) => ' ',
    );
    return (memberCountApproximate ? '≈ ' : '') + formatted +
        (memberCountSource == 'telegram'
            ? ' подписчиков' : ' участников');
  }

  bool matches(String query) {
    final search = [
      title, subtitle, description, category, telegramUrl ?? '', vkUrl ?? '',
    ].join(' ').toLowerCase();
    return search.contains(query);
  }

  static const fallback = <CommunityData>[
    CommunityData(
      id: 'mpeichat',
      title: 'Чат студентов МЭИ',
      subtitle: 'Общение, вопросы и студенческая жизнь',
      description: 'Сообщество студентов МЭИ: общение, вопросы об учёбе '
          'и взаимопомощь. Актуальное количество участников и правила '
          'можно посмотреть по ссылке.',
      category: 'Студенческие чаты',
      iconKind: 'chat',
      telegramUrl: 'https://t.me/mpeichat',
    ),
    CommunityData(
      id: 'mpei_1kurs',
      title: 'Первый курс МЭИ',
      subtitle: 'Для первокурсников',
      description: 'Сообщество первокурсников МЭИ: вопросы о начале учёбы, '
          'расписании, преподавателях и знакомство со студентами.',
      category: 'Первокурсникам',
      iconKind: 'study',
      telegramUrl: 'https://t.me/mpei_1kurs',
    ),
    CommunityData(
      id: 'MPEImai',
      title: 'Подслушано МЭИ',
      subtitle: 'Публикации и студенческие истории',
      description: 'Студенческие публикации и истории из жизни МЭИ. '
          'Актуальный контент и правила — в самом сообществе.',
      category: 'Новости и мемы',
      iconKind: 'news',
      telegramUrl: 'https://t.me/MPEImai',
    ),
    CommunityData(
      id: 'mpeiuniversity',
      title: 'НИУ «МЭИ» | Официальный канал',
      subtitle: 'Новости университета и объявления',
      description: 'Официальный канал МЭИ с новостями университета, '
          'мероприятиями и важными объявлениями.',
      category: 'Новости университета',
      iconKind: 'campus',
      telegramUrl: 'https://t.me/mpeiuniversity',
      vkUrl: 'https://vk.com/mpei_ru',
    ),
    CommunityData(
      id: 'mpei_profcom',
      title: 'Профком студентов МЭИ',
      subtitle: 'Поддержка и возможности студентов',
      description: 'Профсоюзная организация обучающихся МЭИ: новости, '
          'поддержка, инициативы и объявления.',
      category: 'Новости университета',
      iconKind: 'club',
      telegramUrl: 'https://t.me/mpei_profcom',
      vkUrl: 'https://vk.com/profcom_mpei',
    ),
    CommunityData(
      id: 'oss_mpei',
      title: 'Объединённый студсовет МЭИ',
      subtitle: 'Студенческое самоуправление',
      description: 'Объединённый студенческий совет МЭИ: '
          'студенческие проекты, события и инициативы.',
      category: 'Новости университета',
      iconKind: 'events',
      telegramUrl: 'https://t.me/oss_mpei',
      vkUrl: 'https://vk.com/oss_mpei',
    ),
  ];

  static CommunityData? tryParse(Object? value) {
    if (value is! Map) return null;

    final title = value['title'];
    final id = value['id'];
    final description = value['description'];
    if (title is! String || title.trim().isEmpty || id == null) return null;

    final telegram = _safeSocial(value['telegramUrl'], 't.me');
    final vk = _safeSocial(value['vkUrl'], 'vk.com');
    if (telegram == null && vk == null) return null;

    final count = value['memberCount'];
    // User-supplied numbers and old snapshots are no longer treated as counts.
    final source = value['memberCountSource'];
    final verifiedSource = (source == 'telegram' || source == 'vk')
        ? source as String : null;
    final isPending = value['isPending'] == true;
    final members = !isPending &&
            verifiedSource != null &&
            count is int && count >= 0
        ? count : null;

    final kind = value['iconKind'];
    final iconKind = kind is String && communityIconKinds.contains(kind)
        ? kind : 'club';

    final category = value['category'];
    final categoryLabel = category is String && category.isNotEmpty
        ? category : 'Сообщество';

    final subtitle = value['subtitle'];

    return CommunityData(
      id: id.toString(),
      title: title.trim(),
      subtitle: subtitle is String && subtitle.trim().isNotEmpty
          ? subtitle.trim()
          : categoryLabel,
      description: description is String && description.trim().isNotEmpty
          ? description.trim() : 'Информация о сообществе пока не добавлена.',
      category: categoryLabel,
      iconKind: iconKind,
      memberCount: members,
      memberCountSource: members == null ? null : verifiedSource,
      memberCountCheckedAt: members == null
          ? null
          : value['memberCountCheckedAt'] is String
              ? value['memberCountCheckedAt'] as String
              : null,
      memberCountApproximate:
          members != null && value['memberCountApproximate'] == true,
      iconUrl: _safeIconUrl(value['iconUrl']),
      localIconPath:
          isPending && value['localIconPath'] is String
              ? value['localIconPath'] as String : null,
      telegramUrl: telegram,
      vkUrl: vk,
      isPending: isPending,
    );
  }

  static String? _safeIconUrl(Object? input) {
    if (input is! String) return null;
    return RegExp(r'^/services/groups/icons/[0-9]+
    if (input is! String || input.isEmpty) return null;
    final url = Uri.tryParse(input);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.toLowerCase() != expectedHost ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.pathSegments.where((item) => item.isNotEmpty).isEmpty) {
      return null;
    }
    return url.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'category': category,
    'iconKind': iconKind,
    'memberCount': memberCount,
    'memberCountSource': memberCountSource,
    'memberCountCheckedAt': memberCountCheckedAt,
    'memberCountApproximate': memberCountApproximate,
    'iconUrl': iconUrl,
    'localIconPath': localIconPath,
    'telegramUrl': telegramUrl,
    'vkUrl': vkUrl,
    'isPending': isPending,
  };
}

class CommunityDraft {
  const CommunityDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.iconKind,
    this.telegramUrl,
    this.vkUrl,
  });

  final String title;
  final String description;
  final String category;
  final String iconKind;
  final String? telegramUrl;
  final String? vkUrl;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'iconKind': iconKind,
    if (telegramUrl != null) 'telegramUrl': telegramUrl,
    if (vkUrl != null) 'vkUrl': vkUrl,
  };

  CommunityData asPending(int id, {String? localIconPath}) => CommunityData(
    id: 'pending-' + id.toString(),
    title: title,
    subtitle: 'На проверке',
    description: description,
    category: category,
    iconKind: iconKind,
    localIconPath: localIconPath,
    telegramUrl: telegramUrl,
    vkUrl: vkUrl,
    isPending: true,
  );
}

class CommunityApi {
  const CommunityApi();

  Future<List<CommunityData>> getGroups() async {
    final response = await http.get(
      Uri.parse(ApiConfig.baseUrl + '/services/groups'),
    ).timeout(const Duration(seconds: 28));

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить сообщества');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) {
      throw const FormatException('Неправильный ответ сервера сообществ');
    }

    final groups = data.map(CommunityData.tryParse)
        .whereType<CommunityData>()
        .toList();

    if (groups.isEmpty) {
      throw const FormatException('Каталог пуст');
    }

    return groups;
  }

  Future<int> submit(
    CommunityDraft draft, {
    required Uint8List iconBytes,
    required String extension,
  }) async {
    if (iconBytes.length > 700 * 1024 || iconBytes.length < 12) {
      throw Exception('Размер картинки должен быть не больше 700 КБ.');
    }

    final format = extension.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(format)) {
      throw Exception('Выбери JPG, PNG или WebP.');
    }

    http.Response response;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.baseUrl + '/services/groups/submissions'),
      );
      for (final entry in draft.toJson().entries) {
        request.fields[entry.key] = entry.value.toString();
      }
      request.files.add(http.MultipartFile.fromBytes(
        'icon',
        iconBytes,
        filename: 'community_icon.' + format,
      ));

      final stream = await request.send().timeout(
        const Duration(seconds: 20),
      );
      response = await http.Response.fromStream(stream).timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      throw Exception(
        'Нет связи с бэкендом. Проверь USB-подключение или сеть '
        'и повтори отправку.',
      );
    }

    if (response.statusCode == 202) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['id'] is num) {
        return (data['id'] as num).toInt();
      }
      throw const FormatException('Сервер не подтвердил сохранение заявки');
    }

    String? details;
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        final message = data['message'];
        if (message is String) details = message;
        if (message is List) details = message.join(', ');
      }
    } catch (_) {
      // A proxy or failing server may send HTML instead of JSON.
    }

    throw Exception(details ?? switch (response.statusCode) {
      409 => 'Это сообщество уже есть в каталоге или ожидает проверки',
      429 => 'Слишком много заявок. Попробуй через 10 минут',
      503 => 'База данных временно недоступна',
      _ => 'Не удалось отправить заявку (HTTP ' +
          response.statusCode.toString() + ')',
    });
  }
}

/// Local visibility of the current device's submissions while under review.
/// The server retains the authoritative status; local drafts are NOT public.
class PendingCommunityStorage {
  static const _key = 'campus_pending_communities_v1';

  /// Keep the chosen icon visible on the submitting device while pending.
  Future<String?> saveIcon(
    int id,
    Uint8List bytes,
    String extension,
  ) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final iconsDirectory = Directory(
        directory.path + '/community_pending_icons',
      );
      await iconsDirectory.create(recursive: true);
      final safeFormat = ['png', 'jpg', 'jpeg', 'webp'].contains(extension)
          ? extension : 'png';
      final file = File(
        iconsDirectory.path + '/pending_' + id.toString() + '.' + safeFormat,
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<List<CommunityData>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(CommunityData.tryParse)
          .whereType<CommunityData>()
          .where((group) => group.isPending)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(CommunityData community) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await read();
    final groups = [
      community,
      ...previous.where((item) => item.id != community.id),
    ].take(15).toList();
    await prefs.setString(
      _key,
      jsonEncode(groups.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> reconcile(List<CommunityData> published) async {
    final prefs = await SharedPreferences.getInstance();
    final allPending = await read();
    final current = allPending.where((pending) {
      return !published.any((group) =>
        (pending.telegramUrl != null &&
            pending.telegramUrl!.toLowerCase() ==
                group.telegramUrl?.toLowerCase()) ||
        (pending.vkUrl != null &&
            pending.vkUrl!.toLowerCase() ==
                group.vkUrl?.toLowerCase()));
    }).toList();

    if (current.length != allPending.length) {
      await prefs.setString(
        _key,
        jsonEncode(current.map((item) => item.toJson()).toList()),
      );
    }
  }
}
).hasMatch(input)
        ? input : null;
  }

  static String? _safeSocial(Object? input, String expectedHost) {
    if (input is! String || input.isEmpty) return null;
    final url = Uri.tryParse(input);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.toLowerCase() != expectedHost ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.pathSegments.where((item) => item.isNotEmpty).isEmpty) {
      return null;
    }
    return url.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'category': category,
    'iconKind': iconKind,
    'memberCount': memberCount,
    'memberCountSource': memberCountSource,
    'memberCountAsOf': memberCountAsOf,
    'telegramUrl': telegramUrl,
    'vkUrl': vkUrl,
    'isPending': isPending,
  };
}

class CommunityDraft {
  const CommunityDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.iconKind,
    this.memberCount,
    this.telegramUrl,
    this.vkUrl,
  });

  final String title;
  final String description;
  final String category;
  final String iconKind;
  final int? memberCount;
  final String? telegramUrl;
  final String? vkUrl;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'iconKind': iconKind,
    if (memberCount != null) 'memberCount': memberCount,
    if (telegramUrl != null) 'telegramUrl': telegramUrl,
    if (vkUrl != null) 'vkUrl': vkUrl,
  };

  CommunityData asPending(int id) => CommunityData(
    id: 'pending-' + id.toString(),
    title: title,
    subtitle: 'На проверке',
    description: description,
    category: category,
    iconKind: iconKind,
    memberCount: memberCount,
    memberCountSource: memberCount == null ? null : 'self_reported',
    telegramUrl: telegramUrl,
    vkUrl: vkUrl,
    isPending: true,
  );
}

class CommunityApi {
  const CommunityApi();

  Future<List<CommunityData>> getGroups() async {
    final response = await http.get(
      Uri.parse(ApiConfig.baseUrl + '/services/groups'),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить сообщества');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) {
      throw const FormatException('Неправильный ответ сервера сообществ');
    }

    final groups = data.map(CommunityData.tryParse)
        .whereType<CommunityData>()
        .toList();

    if (groups.isEmpty) {
      throw const FormatException('Каталог пуст');
    }

    return groups;
  }

  Future<int> submit(CommunityDraft draft) async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConfig.baseUrl + '/services/groups/submissions'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(draft.toJson()),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception(
        'Нет связи с бэкендом. Проверь USB-подключение или сеть '
        'и повтори отправку.',
      );
    }

    if (response.statusCode == 202) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['id'] is num) {
        return (data['id'] as num).toInt();
      }
      throw const FormatException('Сервер не подтвердил сохранение заявки');
    }

    String? details;
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        final message = data['message'];
        if (message is String) details = message;
        if (message is List) details = message.join(', ');
      }
    } catch (_) {
      // A proxy or failing server may send HTML instead of JSON.
    }

    throw Exception(details ?? switch (response.statusCode) {
      409 => 'Это сообщество уже есть в каталоге или ожидает проверки',
      429 => 'Слишком много заявок. Попробуй через 10 минут',
      503 => 'База данных временно недоступна',
      _ => 'Не удалось отправить заявку (HTTP ' +
          response.statusCode.toString() + ')',
    });
  }
}

/// Local visibility of the current device's submissions while under review.
/// The server retains the authoritative status; local drafts are NOT public.
class PendingCommunityStorage {
  static const _key = 'campus_pending_communities_v1';

  Future<List<CommunityData>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(CommunityData.tryParse)
          .whereType<CommunityData>()
          .where((group) => group.isPending)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(CommunityData community) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await read();
    final groups = [
      community,
      ...previous.where((item) => item.id != community.id),
    ].take(15).toList();
    await prefs.setString(
      _key,
      jsonEncode(groups.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> reconcile(List<CommunityData> published) async {
    final prefs = await SharedPreferences.getInstance();
    final allPending = await read();
    final current = allPending.where((pending) {
      return !published.any((group) =>
        (pending.telegramUrl != null &&
            pending.telegramUrl!.toLowerCase() ==
                group.telegramUrl?.toLowerCase()) ||
        (pending.vkUrl != null &&
            pending.vkUrl!.toLowerCase() ==
                group.vkUrl?.toLowerCase()));
    }).toList();

    if (current.length != allPending.length) {
      await prefs.setString(
        _key,
        jsonEncode(current.map((item) => item.toJson()).toList()),
      );
    }
  }
}
