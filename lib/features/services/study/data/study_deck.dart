import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A card is stored on this device, with a stable ID for learning progress.
class StudyCard {
  const StudyCard({
    required this.id,
    required this.term,
    required this.definition,
  });

  final String id;
  final String term;
  final String definition;

  Map<String, dynamic> toJson() => {
    'id': id,
    'term': term,
    'definition': definition,
  };

  static StudyCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final term = raw['term'];
    final definition = raw['definition'];
    if (id is! String || id.isEmpty ||
        term is! String || term.trim().isEmpty ||
        definition is! String || definition.trim().isEmpty) {
      return null;
    }
    return StudyCard(
      id: id,
      term: term.trim(),
      definition: definition.trim(),
    );
  }
}

class StudyDeck {
  const StudyDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.cards,
    required this.knownCardIds,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final List<StudyCard> cards;
  final Set<String> knownCardIds;
  final DateTime updatedAt;

  int get learnedCount =>
      cards.where((card) => knownCardIds.contains(card.id)).length;

  int get distinctAnswerCount =>
      cards.map((card) => card.definition.trim().toLowerCase()).toSet().length;

  StudyDeck copyWith({
    String? title,
    String? description,
    List<StudyCard>? cards,
    Set<String>? knownCardIds,
  }) {
    final nextCards = cards ?? this.cards;
    final allowedIds = nextCards.map((card) => card.id).toSet();
    return StudyDeck(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      cards: nextCards,
      knownCardIds: (knownCardIds ?? this.knownCardIds)
          .where(allowedIds.contains)
          .toSet(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'cards': cards.map((card) => card.toJson()).toList(),
    'knownCardIds': knownCardIds.toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static StudyDeck? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final description = raw['description'];
    final cardsRaw = raw['cards'];
    if (id is! String || id.isEmpty ||
        title is! String || title.trim().isEmpty ||
        cardsRaw is! List) {
      return null;
    }
    final cards = cardsRaw
        .map(StudyCard.fromJson)
        .whereType<StudyCard>()
        .toList();
    final known = raw['knownCardIds'];
    final cardIds = cards.map((card) => card.id).toSet();
    final storedKnown = known is List
        ? known.whereType<String>().where(cardIds.contains).toSet()
        : <String>{};
    return StudyDeck(
      id: id,
      title: title.trim(),
      description: description is String ? description.trim() : '',
      cards: cards,
      knownCardIds: storedKnown,
      updatedAt: DateTime.tryParse(raw['updatedAt'] is String
              ? raw['updatedAt'] as String
              : '') ??
          DateTime.now(),
    );
  }
}

/// Offline-first store: no BARS authentication or backend request required.
class StudyDeckStore {
  static const _key = 'campus_study_decks_v1';

  Future<List<StudyDeck>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return [];
    final decoded = jsonDecode(saved);
    if (decoded is! List) {
      throw const FormatException('Неверный формат сохранённых наборов');
    }
    return decoded
        .map(StudyDeck.fromJson)
        .whereType<StudyDeck>()
        .toList();
  }

  /// A published deck can be saved to this device once.
  /// Existing copies use the "copy-<public deck id>-" prefix, including
  /// copies saved by older app versions.
  bool containsPublicDeck(List<StudyDeck> decks, int publicDeckId) {
    final prefix = 'copy-$publicDeckId-';
    return decks.any((deck) => deck.id.startsWith(prefix));
  }

  Future<List<StudyDeck>> savePublicDeckOnce(
    StudyDeck copy, {
    required int publicDeckId,
  }) async {
    final current = await load();
    if (containsPublicDeck(current, publicDeckId)) {
      throw const FormatException('Этот набор уже сохранён в «Мои наборы»');
    }
    if (current.any((deck) => deck.id == copy.id)) {
      throw const FormatException('Набор с таким ID уже существует');
    }
    final updated = [copy, ...current];
    await save(updated);
    return updated;
  }

  Future<void> save(List<StudyDeck> decks) async {
    final prefs = await SharedPreferences.getInstance();
    final result = await prefs.setString(
      _key,
      jsonEncode(decks.map((deck) => deck.toJson()).toList()),
    );
    if (!result) {
      throw const FormatException('Не удалось сохранить учебные наборы');
    }
  }
}
