import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';
import 'community_api.dart';

class CommunityAdminItem {
  const CommunityAdminItem({
    required this.community,
    required this.status,
    required this.builtIn,
  });

  final CommunityData community;
  final String status;
  final bool builtIn;

  bool get isPending => status == 'pending';
  bool get isHidden => status == 'hidden';

  static CommunityAdminItem? tryParse(Object? data) {
    if (data is! Map) return null;
    final community = CommunityData.tryParse(data);
    final status = data['status'];
    if (community == null || status is! String ||
        !['pending', 'approved', 'rejected', 'hidden'].contains(status)) {
      return null;
    }
    return CommunityAdminItem(
      community: community,
      status: status,
      builtIn: data['builtIn'] == true,
    );
  }
}

/// Ephemeral server session. Never bundles administrator credentials
/// or permanent secrets into the public Flutter application.
class CommunityAdminApi {
  CommunityAdminApi._();
  static final CommunityAdminApi instance = CommunityAdminApi._();

  String? _cookie;
  String? _csrf;

  bool get isSignedIn => _cookie != null;

  String get _base => ApiConfig.baseUrl + '/services/admin';

  Map<String, String> get imageHeaders =>
      _cookie == null ? const {} : {'Cookie': _cookie!};

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _cookie = null;
    _csrf = null;
    final response = await http.post(
      Uri.parse(_base + '/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_message(response));
    }

    final rawCookie = response.headers['set-cookie'];
    if (rawCookie == null || !rawCookie.startsWith('campus.sid=')) {
      throw Exception('Сервер не выдал сессию администратора');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final csrf = body is Map ? body['csrfToken'] : null;
    if (csrf is! String || csrf.length != 64) {
      throw Exception('Сервер не выдал защитный токен сессии');
    }

    _cookie = rawCookie.split(';').first;
    _csrf = csrf;
  }

  Future<void> checkSession() async {
    final cookie = _cookie;
    if (cookie == null) throw Exception('Войди как администратор');

    final response = await http.get(
      Uri.parse(_base + '/me'),
      headers: {'Cookie': cookie},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      _cookie = null;
      _csrf = null;
      throw Exception('Сессия истекла. Войди ещё раз.');
    }
  }

  Future<void> logout() async {
    final cookie = _cookie;
    final csrf = _csrf;
    _cookie = null;
    _csrf = null;
    if (cookie == null) return;
    try {
      await http.post(
        Uri.parse(_base + '/logout'),
        headers: {
          'Cookie': cookie,
          if (csrf != null) 'X-Community-CSRF': csrf,
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Discarding the in-memory session also prevents further app actions.
    }
  }

  Future<List<CommunityAdminItem>> getGroups() async {
    final response = await _request('GET', '/groups');
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! List) throw const FormatException('Список заявок повреждён');
    return json.map(CommunityAdminItem.tryParse)
        .whereType<CommunityAdminItem>().toList();
  }

  Future<void> review(int id, bool approve) async {
    await _request(
      'PATCH',
      '/submissions/' + id.toString(),
      body: {'status': approve ? 'approved' : 'rejected'},
    );
  }

  Future<void> update(
    String id, {
    required String title,
    required String description,
    required String category,
    required String iconKind,
    String? telegramUrl,
    String? vkUrl,
    bool? hidden,
  }) async {
    await _request(
      'PATCH',
      '/groups/' + Uri.encodeComponent(id),
      body: {
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'iconKind': iconKind,
        'telegramUrl': telegramUrl?.trim() ?? '',
        'vkUrl': vkUrl?.trim() ?? '',
        if (hidden != null) 'hidden': hidden,
      },
    );
  }

  Future<void> updateIcon(String id, Uint8List iconBytes) async {
    final cookie = _cookie;
    final csrf = _csrf;
    if (cookie == null || csrf == null) {
      throw Exception('Войди как администратор');
    }
    if (iconBytes.length < 12 || iconBytes.length > 700 * 1024) {
      throw Exception('Изображение не должно превышать 700 КБ');
    }

    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse(_base + '/groups/' + Uri.encodeComponent(id) + '/icon'),
    );
    request.headers['Cookie'] = cookie;
    request.headers['X-Community-CSRF'] = csrf;
    request.files.add(
      http.MultipartFile.fromBytes(
        'icon', iconBytes, filename: 'community_icon.png',
      ),
    );

    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 15)),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      _cookie = null;
      _csrf = null;
      throw Exception('Сессия администратора истекла');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(response));
    }
  }

  Future<void> restore(String id) async {
    await _request(
      'PATCH',
      '/groups/' + Uri.encodeComponent(id),
      body: {'hidden': false},
    );
  }

  Future<void> delete(String id) async {
    await _request('DELETE', '/groups/' + Uri.encodeComponent(id));
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final cookie = _cookie;
    if (cookie == null) throw Exception('Войди как администратор');

    final request = http.Request(method, Uri.parse(_base + path));
    request.headers['Cookie'] = cookie;
    if (method != 'GET' && method != 'HEAD') {
      final csrf = _csrf;
      if (csrf == null) {
        throw Exception('Сессия администратора не подтверждена');
      }
      request.headers['X-Community-CSRF'] = csrf;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 12)),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      _cookie = null;
      _csrf = null;
      throw Exception('Нет прав администратора или сессия истекла');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(response));
    }
    return response;
  }

  String _message(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map) {
        final message = value['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }
    } catch (_) {}
    return 'Ошибка администратора: HTTP ' + response.statusCode.toString();
  }
}
