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

  test('one public deck can be saved only once, including after a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final published = PublicStudyDeck.fromJson(data);
    final store = StudyDeckStore();
    final first = published.asPersonalCopy();
    final saved = await store.savePublicDeckOnce(
      first,
      publicDeckId: published.id,
    );
    expect(saved, hasLength(1));
    expect(store.containsPublicDeck(saved, published.id), isTrue);

    final second = published.asPersonalCopy();
    await expectLater(
      StudyDeckStore().savePublicDeckOnce(
        second,
        publicDeckId: published.id,
      ),
      throwsA(isA<FormatException>()),
    );
    final after = await StudyDeckStore().load();
    expect(after, hasLength(1));
    expect(after.single.id, first.id);
  });

  test('different public decks can each be saved once', () async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyDeckStore();
    final first = PublicStudyDeck.fromJson(data);
    final second = PublicStudyDeck.fromJson({...data, 'id': 35});
    await store.savePublicDeckOnce(
      first.asPersonalCopy(),
      publicDeckId: first.id,
    );
    await store.savePublicDeckOnce(
      second.asPersonalCopy(),
      publicDeckId: second.id,
    );
    final saved = await store.load();
    expect(saved, hasLength(2));
    expect(store.containsPublicDeck(saved, first.id), isTrue);
    expect(store.containsPublicDeck(saved, second.id), isTrue);
  });

  test('previously saved copies are recognized after upgrade', () async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyDeckStore();
    final item = PublicStudyDeck.fromJson(data);
    final oldCopy = item.asPersonalCopy();
    await store.save([oldCopy]);
    expect(store.containsPublicDeck(await store.load(), item.id), isTrue);
    await expectLater(
      store.savePublicDeckOnce(item.asPersonalCopy(), publicDeckId: item.id),
      throwsA(isA<FormatException>()),
    );
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
