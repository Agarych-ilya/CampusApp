import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '/core/config/api_config.dart';

const marketCategories = [
  'Все', 'Учебники', 'Техника', 'Одежда', 'Даром', 'Аксессуары', 'Другое',
];
const foundCategories = [
  'Все', 'Документы', 'Электроника', 'Ключи', 'Одежда', 'Другое',
];

class CampusListing {
  const CampusListing({
    required this.id,
    required this.kind,
    required this.category,
    required this.title,
    required this.description,
    required this.price,
    required this.condition,
    required this.location,
    required this.authorName,
    required this.telegram,
    required this.status,
    required this.isMine,
    required this.createdAt,
    required this.photoUrls,
  });

  final int id;
  final String kind;
  final String category;
  final String title;
  final String description;
  final int? price;
  final String? condition;
  final String? location;
  final String authorName;
  final String telegram;
  final String status;
  final bool isMine;
  final DateTime createdAt;
  final List<String> photoUrls;

  bool get isClosed => status == 'closed';
  bool get isFree => kind == 'market' && price == 0;

  String get priceLabel {
    if (kind != 'market') return '';
    if (price == 0) return 'Даром';
    final value = (price ?? 0).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$value ₽';
  }

  String get ageLabel {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'только что';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} мин';
    if (elapsed.inHours < 24) return '${elapsed.inHours} ч';
    return '${elapsed.inDays} дн';
  }

  static CampusListing fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Неверный формат объявления');
    }
    final id = value['id'];
    final photos = value['photoUrls'];
    return CampusListing(
      id: id is num ? id.toInt() : int.parse('$id'),
      kind: value['kind']?.toString() ?? '',
      category: value['category']?.toString() ?? '',
      title: value['title']?.toString() ?? '',
      description: value['description']?.toString() ?? '',
      price: value['price'] is num ? (value['price'] as num).toInt() : null,
      condition: value['condition']?.toString(),
      location: value['location']?.toString(),
      authorName: value['authorName']?.toString() ?? 'Студент',
      telegram: value['telegram']?.toString() ?? '',
      status: value['status']?.toString() ?? 'active',
      isMine: value['isMine'] == true,
      createdAt: DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      photoUrls: photos is List
          ? photos.whereType<String>()
              .where((path) =>
                  RegExp(r'^/services/listings/\d+/photos/[0-2]$').hasMatch(path))
              .toList()
          : const [],
    );
  }
}

class ListingDraft {
  const ListingDraft({
    required this.kind,
    required this.category,
    required this.title,
    required this.description,
    required this.authorName,
    required this.telegram,
    this.price,
    this.condition,
    this.location,
  });

  final String kind;
  final String category;
  final String title;
  final String description;
  final String authorName;
  final String telegram;
  final int? price;
  final String? condition;
  final String? location;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'category': category,
    'title': title.trim(),
    'description': description.trim(),
    'authorName': authorName.trim(),
    'telegram': telegram.trim(),
    if (kind == 'market') 'price': price ?? 0,
    if (kind == 'market' && condition != null) 'condition': condition,
    if (location != null) 'location': location!.trim(),
  };
}

class ListingsApi {
  ListingsApi._();
  static final ListingsApi instance = ListingsApi._();

  String? _cookie;
  String? _csrf;
  String? _sessionGroup;
  Future<void>? _pendingEnsureSession;
  DateTime? _retryBARSAfter;
  String? _lastBARSError;

  String get _base => ApiConfig.baseUrl + '/services/listings';
  bool get hasSession => _cookie != null && _csrf != null;

  Map<String, String> _headers({bool json = false, bool change = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (_cookie != null) 'Cookie': _cookie!,
    if (change && _csrf != null) 'X-Listing-CSRF': _csrf!,
  };

  Uri imageUri(String path) =>
      Uri.parse(ApiConfig.baseUrl + path);

  String _error(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map) {
        final message = json['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }
    } catch (_) {}
    if (response.statusCode == 403 || response.statusCode == 401) {
      return 'Нет подтверждённой сессии БАРС. Открой профиль и повтори.';
    }
    return 'Ошибка сервера (HTTP ${response.statusCode})';
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool change = false,
  }) async {
    final request = http.Request(method, Uri.parse(_base + path));
    request.headers.addAll(_headers(json: body != null, change: change));
    if (body != null) request.body = jsonEncode(body);
    // BARS authentication verifies two independent protected pages.
    // 17 seconds can expire before both 9-second upstream requests finish.
    final timeout = path == '/bars-login'
        ? const Duration(seconds: 120)
        : const Duration(seconds: 17);
    final response = await http.Response.fromStream(
      await request.send().timeout(timeout),
    ).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response));
    }
    return response;
  }

  Future<List<CampusListing>> load({
    required String kind,
    String? query,
    String? category,
    String sort = 'recent',
    bool mine = false,
  }) async {
    if (mine) await ensureSession();
    final params = <String, String>{
      'kind': kind,
      'sort': sort,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category != 'Все' && category != 'Даром')
        'category': category,
      if (category == 'Даром') 'free': 'true',
      if (mine) 'mine': 'true',
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers())
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) throw Exception(_error(response));
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const FormatException('Некорректный список');
    return data.map(CampusListing.fromJson).toList();
  }

  Future<CampusListing> get(int id) async {
    final r = await _send('GET', '/$id');
    return CampusListing.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// Multiple widgets can request Campus sessions simultaneously. Never
  /// submit a burst of identical BARS verification requests on a failure.
  /// A user-triggered "refreshBarsRole" bypasses the cooldown.
  Future<void> ensureSession({bool requireGroup = false}) async {
    final pending = _pendingEnsureSession;
    if (pending != null) {
      await pending;
    } else {
      final now = DateTime.now();
      if (_retryBARSAfter != null && now.isBefore(_retryBARSAfter!)) {
        throw Exception(_lastBARSError ??
            'Проверка БАРС временно недоступна. Повтори попытку позже.');
      }
      final running = _ensureSessionOnce();
      _pendingEnsureSession = running;
      try {
        await running;
        _retryBARSAfter = null;
        _lastBARSError = null;
      } catch (error) {
        _retryBARSAfter = DateTime.now().add(const Duration(seconds: 30));
        _lastBARSError = error.toString().replaceFirst('Exception: ', '');
        rethrow;
      } finally {
        if (identical(_pendingEnsureSession, running)) {
          _pendingEnsureSession = null;
        }
      }
    }
    // Never infer study-group access from an authenticated Campus cookie.
    if (requireGroup && (_sessionGroup?.trim().isEmpty ?? true)) {
      throw Exception('БАРС не подтвердил твою учебную группу');
    }
  }

  Future<void> _ensureSessionOnce() async {
    if (hasSession) {
      try {
        final r = await _send('GET', '/session');
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        if (data is Map && data['authenticated'] == true) {
          _sessionGroup = data['group'] is String
              ? (data['group'] as String).trim() : null;
          return;
        }
      } catch (_) {
        // The existing Campus session may have expired.
      }
    }
    _cookie = null;
    _csrf = null;
    _sessionGroup = null;
    final address = Uri.tryParse(ApiConfig.baseUrl);
    if (address == null ||
        !(address.scheme == 'https' ||
          (address.scheme == 'http' &&
            ['127.0.0.1', 'localhost'].contains(address.host)))) {
      throw Exception(
        'Для публикации через БАРС требуется HTTPS или USB ADB Reverse '
        'с адресом 127.0.0.1:8000.',
      );
    }
    final cookies = await WebViewCookieManager().getCookies(
      domain: Uri.parse('https://bars.mpei.ru/bars_web/ST/Student/ListStudent'),
    );
    final safeName = RegExp(r'^[a-zA-Z0-9_.-]+$');
    final allowed = cookies.where((cookie) =>
        safeName.hasMatch(cookie.name) &&
        cookie.value.isNotEmpty &&
        !cookie.value.contains(RegExp(r'[\r\n;]'))).toList();
    if (allowed.isEmpty) {
      throw Exception('Сессия БАРС не найдена. Войди в БАРС в CampusApp.');
    }
    final cookieHeader = allowed
        .map((item) => item.name + '=' + item.value).join('; ');
    if (cookieHeader.length > 8192) {
      throw Exception('Слишком много cookie БАРС');
    }
    final response = await _send(
      'POST', '/bars-login',
      body: {'cookieHeader': cookieHeader},
    );
    final rawCookie = response.headers['set-cookie'];
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    final csrf = result is Map ? result['csrfToken'] : null;
    if (rawCookie == null || !rawCookie.startsWith('campus.sid=') ||
        csrf is! String || csrf.length != 64) {
      throw Exception('Сервер не подтвердил сессию объявлений');
    }
    _cookie = rawCookie.split(';').first;
    _csrf = csrf;
    _sessionGroup = result is Map && result['group'] is String
        ? (result['group'] as String).trim() : null;
  }

  /// Hand existing BARS cookies to the authenticated backend to perform
  /// a server-side roster refresh. Never read/parse student HTML in Flutter.
  /// Cookies are not stored in the backend; transport must be TLS or ADB.
  Future<String> barsCookiesForServer() async {
    final address = Uri.tryParse(ApiConfig.baseUrl);
    if (address == null ||
        !(address.scheme == 'https' ||
          (address.scheme == 'http' &&
           ['127.0.0.1', 'localhost'].contains(address.host)))) {
      throw Exception('Для синхронизации БАРС нужен HTTPS или USB ADB Reverse');
    }
    final cookies = await WebViewCookieManager().getCookies(
      domain: Uri.parse('https://bars.mpei.ru/bars_web/ST/Student/ListStudent'),
    );
    final allowed = cookies.where((cookie) =>
        RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(cookie.name) &&
        cookie.value.isNotEmpty &&
        !cookie.value.contains(RegExp(r'[\r\n;]'))).toList();
    if (allowed.isEmpty) throw Exception('Сессия БАРС не найдена. Выполни вход.');
    final cookieHeader = allowed.map((c) => '${c.name}=${c.value}').join('; ');
    if (cookieHeader.length > 8192) throw Exception('Слишком много cookie БАРС');
    return cookieHeader;
  }

  /// Recheck the user's existing BARS WebView cookies to obtain their
  /// current university role. This never accepts a role/name from Flutter.
  Future<void> refreshBarsRole() async {
    final oldCookie = _cookie;
    final oldCsrf = _csrf;
    final oldGroup = _sessionGroup;
    _cookie = null;
    _csrf = null;
    _sessionGroup = null;
    // Explicit user action must be able to retry immediately.
    _retryBARSAfter = null;
    _lastBARSError = null;
    try {
      await ensureSession(requireGroup: true);
    } catch (_) {
      // Keep using the previous CampusApp session for ordinary features
      // if the external BARS role check is temporarily unavailable.
      _cookie = oldCookie;
      _csrf = oldCsrf;
      _sessionGroup = oldGroup;
      rethrow;
    }
  }

  /// Reuse the already verified BARS identity for publishing and rating
  /// study decks. No second password or separate administrator role.
  Future<Map<String, String>> studyAuthHeaders() async {
    await ensureSession();
    return {
      'Cookie': _cookie!,
      'X-Listing-CSRF': _csrf!,
    };
  }

  Future<Map<String, String>> scheduleNotesAuthHeaders({bool write = false}) async {
    await ensureSession(requireGroup: true);
    return {
      'Cookie': _cookie!,
      if (write) 'X-Listing-CSRF': _csrf!,
    };
  }

  Map<String, String> get studyReadHeaders =>
      _cookie == null ? const {} : {'Cookie': _cookie!};

  Future<CampusListing> create(
    ListingDraft draft,
    List<Uint8List> photos,
  ) async {
    await ensureSession();
    final request = http.MultipartRequest('POST', Uri.parse(_base));
    request.headers.addAll(_headers(change: true));
    for (final entry in draft.toJson().entries) {
      request.fields[entry.key] = entry.value.toString();
    }
    if (photos.length > 3) {
      throw Exception('Можно загрузить не больше трёх фотографий');
    }
    for (var index = 0; index < photos.length; index++) {
      final data = photos[index];
      if (data.length > 5 * 1024 * 1024 || data.length < 12) {
        throw Exception('Каждое фото должно быть размером до 5 МБ');
      }
      request.files.add(http.MultipartFile.fromBytes(
        'photos',
        data,
        filename: 'listing_photo_${index + 1}',
      ));
    }
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 35)),
    ).timeout(const Duration(seconds: 35));
    if (response.statusCode != 201) throw Exception(_error(response));
    return CampusListing.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }

  Future<CampusListing> update(int id, Map<String, dynamic> fields) async {
    await ensureSession();
    final r = await _send('PATCH', '/$id', body: fields, change: true);
    return CampusListing.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  Future<void> delete(int id) async {
    await ensureSession();
    await _send('DELETE', '/$id', change: true);
  }

  Future<void> report(int id, String reason) async {
    await _send('POST', '/$id/report', body: {'reason': reason});
  }
}

class ListingFavorites {
  static const _key = 'campus_listing_favorites_v1';

  Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> save(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key, ids.map((id) => id.toString()).toList(),
    );
  }
}
