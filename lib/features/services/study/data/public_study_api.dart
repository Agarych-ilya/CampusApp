import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '/core/config/api_config.dart';
import '/features/services/listings/data/listings_api.dart';
import 'study_deck.dart';

class PublicStudyDeck {
  const PublicStudyDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.cardCount,
    required this.rating,
    required this.ratingCount,
    required this.myRating,
    required this.isMine,
    required this.updatedAt,
    this.cards = const [],
  });

  final int id;
  final String title;
  final String description;
  final String authorName;
  final int cardCount;
  final double rating;
  final int ratingCount;
  final int? myRating;
  final bool isMine;
  final DateTime updatedAt;
  final List<StudyCard> cards;

  static PublicStudyDeck fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Некорректный набор');
    final cards = raw['cards'];
    return PublicStudyDeck(
      id: (raw['id'] as num).toInt(),
      title: raw['title'] as String,
      description: raw['description'] as String,
      authorName: raw['authorName'] as String,
      cardCount: (raw['cardCount'] as num).toInt(),
      rating: (raw['rating'] as num).toDouble(),
      ratingCount: (raw['ratingCount'] as num).toInt(),
      myRating: (raw['myRating'] as num?)?.toInt(),
      isMine: raw['isMine'] == true,
      updatedAt: DateTime.tryParse(raw['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      cards: cards is List
          ? cards.map(StudyCard.fromJson).whereType<StudyCard>().toList()
          : const [],
    );
  }

  StudyDeck asStudyDeck() => StudyDeck(
    id: 'published-$id',
    title: title,
    description: description,
    cards: cards,
    knownCardIds: const {},
    updatedAt: updatedAt,
  );

  StudyDeck asPersonalCopy() {
    final unique = DateTime.now().microsecondsSinceEpoch.toString() +
        '-' + Random().nextInt(1 << 30).toString();
    return StudyDeck(
      id: 'copy-$id-$unique',
      title: title,
      description: description,
      cards: cards,
      knownCardIds: const {},
      updatedAt: DateTime.now(),
    );
  }
}

/// Public catalog uses the same server as the rest of CampusApp.
/// Publishing/rating is available after the existing BARS session is verified.
class PublicStudyApi {
  PublicStudyApi._();
  static final PublicStudyApi instance = PublicStudyApi._();

  String get _url => '${ApiConfig.baseUrl}/services/study/decks';

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }
    } catch (_) {}
    return 'Ошибка сервера (HTTP ${response.statusCode})';
  }

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = authenticated
        ? await ListingsApi.instance.studyAuthHeaders()
        : ListingsApi.instance.studyReadHeaders;
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 18),
      );
      final response = await http.Response.fromStream(streamed).timeout(
        const Duration(seconds: 18),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on Exception {
      rethrow;
    }
  }

  Future<List<PublicStudyDeck>> search({
    String query = '',
    String sort = 'recent',
  }) async {
    final uri = Uri.parse(_url).replace(queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'sort': sort,
    });
    final data = await _request('GET', uri);
    if (data is! List) throw const FormatException('Некорректный каталог');
    return data.map(PublicStudyDeck.fromJson).toList();
  }

  Future<PublicStudyDeck> get(int id) async =>
      PublicStudyDeck.fromJson(await _request('GET', Uri.parse('$_url/$id')));

  Future<PublicStudyDeck> publish(
    StudyDeck deck, {
    required String authorName,
  }) async {
    return PublicStudyDeck.fromJson(await _request(
      'POST',
      Uri.parse(_url),
      authenticated: true,
      body: {
        'localDeckId': deck.id,
        'title': deck.title,
        'description': deck.description,
        'authorName': authorName,
        'cards': deck.cards.map((card) => card.toJson()).toList(),
      },
    ));
  }

  Future<PublicStudyDeck> rate(int id, int stars) async =>
      PublicStudyDeck.fromJson(await _request(
        'POST',
        Uri.parse('$_url/$id/rating'),
        authenticated: true,
        body: {'stars': stars},
      ));

  Future<void> delete(int id) async {
    await _request('DELETE', Uri.parse('$_url/$id'), authenticated: true);
  }
}
