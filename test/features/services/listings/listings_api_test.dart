import 'package:flutter_test/flutter_test.dart';
import 'package:campusapp/features/services/listings/data/listings_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final market = {
    'id': 42,
    'kind': 'market',
    'category': 'Техника',
    'title': 'Наушники',
    'description': 'Хорошее состояние, есть коробка.',
    'price': 1500,
    'condition': 'good',
    'location': 'МЭИ',
    'authorName': 'Иван К.',
    'telegram': 'campus_ivan',
    'status': 'active',
    'isMine': false,
    'createdAt': '2026-11-07T12:00:00.000Z',
    'photoUrls': [
      '/services/listings/42/photos/0',
      'https://untrusted.example.com/photo',
    ],
  };

  test('parses a market listing without unsafe external image paths', () {
    final item = CampusListing.fromJson(market);
    expect(item.id, 42);
    expect(item.priceLabel, '1 500 ₽');
    expect(item.photoUrls, ['/services/listings/42/photos/0']);
    expect(item.isMine, false);
  });

  test('free listings have a distinct price label', () {
    final item = CampusListing.fromJson({...market, 'price': 0});
    expect(item.isFree, true);
    expect(item.priceLabel, 'Даром');
  });

  test('listing editor draft omits market fields for lost objects', () {
    const draft = ListingDraft(
      kind: 'lost',
      category: 'Документы',
      title: 'Пропуск',
      description: 'Потерял пропуск в аудитории',
      location: 'Корпус А',
      authorName: 'Иван К.',
      telegram: '@campus_ivan',
    );
    final json = draft.toJson();
    expect(json['kind'], 'lost');
    expect(json.containsKey('price'), false);
    expect(json['telegram'], '@campus_ivan');
  });

  test('closed listings are flagged as closed', () {
    final listing = CampusListing.fromJson({
      ...market,
      'kind': 'found',
      'status': 'closed',
      'price': null,
    });
    expect(listing.isClosed, true);
    expect(listing.priceLabel, '');
  });
}
