import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/services/study/data/public_study_api.dart';
import 'package:campusapp/features/services/study/data/study_deck.dart';

void main() {
  final data = <String, dynamic>{
    'id': 34,
    'title': 'Теория управления',
    'description': 'Экзамен',
    'authorName': 'Студент МЭИ',
    'cardCount': 2,
    'rating': 4.5,
    'ratingCount': 12,
    'myRating': 5,
    'isMine': false,
    'updatedAt': '2026-11-08T00:00:00.000Z',
    'cards': [
      {'id': 'a', 'term': 'Устойчивость', 'definition': 'Свойство системы'},
      {'id': 'b', 'term': 'Регулирование', 'definition': 'Управление'},
    ],
  };

  test('public deck parses an actual rating and its star count', () {
    final deck = PublicStudyDeck.fromJson(data);
    expect(deck.rating, 4.5);
    expect(deck.ratingCount, 12);
    expect(deck.myRating, 5);
    expect(deck.authorName, 'Студент МЭИ');
    expect(deck.cards.length, 2);
  });

  test('catalog previews have no cards until details are loaded', () {
    final preview = PublicStudyDeck.fromJson({
      ...data,
      'cards': null,
    });
    expect(preview.cardCount, 2);
    expect(preview.cards, isEmpty);
  });

  test('two imports persist as two distinct local decks', () async {
    SharedPreferences.setMockInitialValues({});
    final published = PublicStudyDeck.fromJson(data);
    final store = StudyDeckStore();

    final first = published.asPersonalCopy();
    final afterFirst = await store.addNewCopy(first);
    expect(afterFirst, hasLength(1));

    final second = published.asPersonalCopy();
    final afterSecond = await store.addNewCopy(second);
    expect(afterSecond, hasLength(2));
    expect(afterSecond.map((deck) => deck.id).toSet(), hasLength(2));

    // Verify persistence rather than relying only on in-memory state.
    final restored = await StudyDeckStore().load();
    expect(restored, hasLength(2));
    expect(restored[0].id, second.id);
    expect(restored[1].id, first.id);
  });

  test('duplicate copy IDs never overwrite an existing deck', () async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyDeckStore();
    final first = PublicStudyDeck.fromJson(data).asPersonalCopy();
    await store.addNewCopy(first);

    await expectLater(
      store.addNewCopy(first),
      throwsA(isA<FormatException>()),
    );
    final remaining = await store.load();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, first.id);
  });

  test('saving a public deck creates a separate local copy', () {
    final original = PublicStudyDeck.fromJson(data);
    final copy = original.asPersonalCopy();
    final another = original.asPersonalCopy();
    expect(copy.title, original.title);
    expect(copy.cards.length, 2);
    expect(copy.id, isNot(original.id.toString()));
    expect(another.id, isNot(copy.id));
    expect(copy.knownCardIds, isEmpty);
  });
}
