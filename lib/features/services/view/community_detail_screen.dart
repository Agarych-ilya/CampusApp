import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/community_api.dart';
import '../widgets/community_avatar.dart';

/// Public community information; tapping social links never auto-joins.
class CommunityDetailScreen extends StatelessWidget {
  const CommunityDetailScreen({super.key, required this.community});

  final CommunityData community;

  Future<void> _openSocial(
    BuildContext context,
    String link,
  ) async {
    try {
      final opened = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );

      if (opened) return;
    } catch (_) {
      // Show the same actionable message for unsupported social apps.
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть ссылку. Проверь подключение.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = CommunityAvatar.colorsFor(community.iconKind).first;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сообщество',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 29, 20, 29),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  CommunityAvatar(
                    community: community,
                    size: 96,
                  ),
                  const SizedBox(height: 19),
                  Text(
                    community.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    community.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      community.category,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (community.isPending) ...[
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 17),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Ожидает модерации · видно только тебе',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 23),
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.groups_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Участники сообщества',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          community.membersLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (community.memberCountSource == 'self_reported') ...[
                          const SizedBox(height: 4),
                          Text(
                            'Количество указано автором, не проверено',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'О сообществе',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              community.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: muted,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Социальные сети',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (community.telegramUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF229ED9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    onPressed: () => _openSocial(
                      context, community.telegramUrl!,
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Открыть Telegram',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            if (community.vkUrl != null)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0077FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  onPressed: () => _openSocial(
                    context, community.vkUrl!,
                  ),
                  icon: const Text(
                    'VK',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  label: const Text(
                    'Открыть ВКонтакте',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const SizedBox(height: 17),
            Text(
              'Ссылки открываются во внешних приложениях. '
              'CampusApp не управляет содержимым сообществ.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
