import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusapp/features/services/study/data/study_deck.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const first = StudyCard(
    id: 'a',
    term: 'Термин 1',
    definition: 'Определение 1',
  );
  const second = StudyCard(
    id: 'b',
    term: 'Термин 2',
    definition: 'Определение 2',
  );

  StudyDeck sample() => StudyDeck(
    id: 'deck-1',
    title: 'Мои карточки',
    description: 'Тестовый набор',
    cards: [first, second],
    knownCardIds: {'a'},
    updatedAt: DateTime.utc(2026, 11, 7),
  );

  test('deck serialization preserves cards and study progress', () {
    final restored = StudyDeck.fromJson(sample().toJson());
    expect(restored, isNotNull);
    expect(restored!.title, 'Мои карточки');
    expect(restored.cards.map((card) => card.term),
        ['Термин 1', 'Термин 2']);
    expect(restored.knownCardIds, {'a'});
    expect(restored.learnedCount, 1);
    expect(restored.distinctAnswerCount, 2);
  });

  test('editing cards prunes progress for deleted cards', () {
    final changed = sample().copyWith(cards: [second]);
    expect(changed.cards, hasLength(1));
    expect(changed.knownCardIds, isEmpty);
    expect(changed.learnedCount, 0);
  });

  test('invalid cards are ignored on load', () {
    final data = sample().toJson();
    data['cards'] = [
      first.toJson(),
      {'id': 'bad', 'term': '', 'definition': 'missing term'},
    ];
    data['knownCardIds'] = ['a', 'bad'];
    final restored = StudyDeck.fromJson(data);
    expect(restored!.cards, hasLength(1));
    expect(restored.knownCardIds, {'a'});
  });

  test('local store saves and restores a deck', () async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyDeckStore();
    await store.save([sample()]);
    final decks = await store.load();
    expect(decks, hasLength(1));
    expect(decks.first.cards.length, 2);
    expect(decks.first.learnedCount, 1);
  });
}
