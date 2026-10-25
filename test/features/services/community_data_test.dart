import 'package:campusapp/features/services/data/community_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the curated MPEI directory has unique names and themed icons', () {
    final communities = CommunityData.fallback;
    expect(communities, hasLength(6));
    expect(communities.map((group) => group.iconKind).toSet(), hasLength(6));
    expect(communities.first.title, 'Чат студентов МЭИ');
    expect(communities[2].title, 'Подслушано МЭИ');
    expect(communities[3].vkUrl, 'https://vk.com/mpei_ru');
  });

  test('parses server approved groups and their social networks', () {
    final group = CommunityData.tryParse({
      'id': 'community-1',
      'title': 'МЭИ Клуб',
      'description': 'Клуб инициативных студентов',
      'subtitle': 'Для студентов',
      'category': 'Клубы и интересы',
      'iconKind': 'club',
      'memberCount': 1250,
      'memberCountSource': 'self_reported',
      'telegramUrl': 'https://t.me/mpei_club',
      'vkUrl': 'https://vk.com/mpei_club',
    });

    expect(group, isNotNull);
    expect(group!.membersLabel, '1 250 участников');
    expect(group.telegramUrl, 'https://t.me/mpei_club');
    expect(group.vkUrl, 'https://vk.com/mpei_club');
    expect(group.matches('инициативных'), isTrue);
    expect(group.matches('робототехника'), isFalse);
  });

  test('avoids presenting channel snapshots as live member counts', () {
    final channel = CommunityData.fallback[2];
    expect(channel.memberCountSource, 'telegram_snapshot');
    expect(channel.memberCountAsOf, isNotNull);
    expect(channel.membersLabel, '2 392 подписчиков');
  });

  test('rejects untrusted links from a malformed API response', () {
    final group = CommunityData.tryParse({
      'id': 10,
      'title': 'Поддельная группа',
      'telegramUrl': 'https://evil.example/fake',
      'vkUrl': 'javascript:alert(1)',
    });

    expect(group, isNull);
  });

  test('new submissions remain local-only pending records', () {
    const draft = CommunityDraft(
      title: 'Мой студенческий клуб',
      description: 'Общаемся и готовим совместные мероприятия.',
      category: 'Клубы и интересы',
      iconKind: 'club',
      telegramUrl: 'https://t.me/my_mpei_club',
      memberCount: 50,
    );

    final pending = draft.asPending(42);
    expect(pending.isPending, isTrue);
    expect(pending.id, 'pending-42');
    expect(pending.memberCountSource, 'self_reported');
    expect(
      CommunityData.tryParse(pending.toJson())!.isPending,
      isTrue,
    );
  });
}
