import 'package:campusapp/features/services/data/community_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('curated groups keep unique fallback pictograms', () {
    final communities = CommunityData.fallback;
    expect(communities, hasLength(6));
    expect(communities.map((group) => group.iconKind).toSet(), hasLength(6));
    expect(communities.first.title, 'Чат студентов МЭИ');
    expect(communities[2].title, 'Подслушано МЭИ');
    expect(communities[3].vkUrl, 'https://vk.com/mpei_ru');
  });

  test('verified Telegram counts are parsed with their timestamp', () {
    final group = CommunityData.tryParse({
      'id': 'community-1',
      'title': 'МЭИ Клуб',
      'description': 'Клуб инициативных студентов',
      'subtitle': 'Для студентов',
      'category': 'Клубы и интересы',
      'iconKind': 'club',
      'memberCount': 1250,
      'memberCountSource': 'telegram',
      'memberCountCheckedAt': '2026-10-25T12:00:00.000Z',
      'memberCountApproximate': true,
      'iconUrl': '/services/groups/icons/42',
      'telegramUrl': 'https://t.me/mpei_club',
      'vkUrl': 'https://vk.com/mpei_club',
    });

    expect(group, isNotNull);
    expect(group!.membersLabel, '≈ 1 250 подписчиков');
    expect(group.memberCountCheckedAt, contains('2026-10-25'));
    expect(group.iconUrl, '/services/groups/icons/42');
    expect(group.matches('инициативных'), isTrue);
    expect(group.matches('робототехника'), isFalse);
  });

  test('automated VK audience counts can be displayed', () {
    final group = CommunityData.tryParse({
      'id': 'community-2',
      'title': 'Клуб МЭИ ВК',
      'iconKind': 'club',
      'memberCount': 380,
      'memberCountSource': 'vk',
      'vkUrl': 'https://vk.com/mpei_club',
    });

    expect(group!.membersLabel, '380 участников');
  });

  test('old manually entered counts and snapshots are ignored', () {
    final manual = CommunityData.tryParse({
      'id': 'old-pending',
      'title': 'Старый клуб',
      'memberCount': 999999,
      'memberCountSource': 'self_reported',
      'telegramUrl': 'https://t.me/mpei_club',
    });

    expect(manual!.memberCount, isNull);
    expect(CommunityData.fallback[2].memberCount, isNull);
  });

  test('rejects unsafe links and icon URL traversal', () {
    final invalid = CommunityData.tryParse({
      'id': 10,
      'title': 'Поддельная группа',
      'telegramUrl': 'https://evil.example/fake',
      'vkUrl': 'javascript:alert(1)',
    });
    expect(invalid, isNull);

    final valid = CommunityData.tryParse({
      'id': 11,
      'title': 'Просто сообщество',
      'telegramUrl': 'https://t.me/mpei_club',
      'iconUrl': '/services/groups/icons/../../private',
    });
    expect(valid!.iconUrl, isNull);
  });

  test('new submissions do not contain a manual count', () {
    const draft = CommunityDraft(
      title: 'Мой студенческий клуб',
      description: 'Общаемся и готовим совместные мероприятия.',
      category: 'Клубы и интересы',
      iconKind: 'club',
      telegramUrl: 'https://t.me/my_mpei_club',
    );

    expect(draft.toJson().containsKey('memberCount'), isFalse);
    final pending = draft.asPending(
      42,
      localIconPath: '/data/user/0/campus_pending_icons/icon.jpg',
    );
    expect(pending.isPending, isTrue);
    expect(pending.memberCount, isNull);
    expect(pending.localIconPath, isNotNull);
    expect(
      CommunityData.tryParse(pending.toJson())!.isPending,
      isTrue,
    );
  });
}
