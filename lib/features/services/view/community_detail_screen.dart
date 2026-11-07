import 'dart:typed_data';

import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/community_api.dart';
import '../widgets/community_avatar.dart';
import 'community_edit_screen.dart';

/// Public community information; tapping social links never auto-joins.
class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.community,
    this.onEditAvatar,
    this.canEditAvatar = false,
    this.onChanged,
  });

  final CommunityData community;
  final Future<Uint8List?> Function()? onEditAvatar;
  final bool canEditAvatar;
  final Future<void> Function()? onChanged;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  late CommunityData _currentCommunity;
  CommunityData get community => _currentCommunity;
  Uint8List? _editedAvatar;
  bool _editingAvatar = false;

  @override
  void initState() {
    super.initState();
    _currentCommunity = widget.community;
  }

  Future<void> _editInfo() async {
    if (!widget.canEditAvatar || community.isPending) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityEditScreen(community: community),
      ),
    );
    if (changed != true || !mounted) return;
    try {
      final updated = await const CommunityApi().getGroups();
      if (!mounted) return;
      final matches = updated.where((group) => group.id == community.id);
      if (matches.isNotEmpty) {
        setState(() => _currentCommunity = matches.first);
      }
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные сообщества обновлены')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Изменения сохранены. Обнови страницу, чтобы увидеть новые данные.',
          )),
        );
      }
    }
  }

  Future<void> _changeAvatar() async {
    if (_editingAvatar || widget.onEditAvatar == null) return;
    setState(() => _editingAvatar = true);
    try {
      final bytes = await widget.onEditAvatar!();
      if (bytes != null && mounted) {
        setState(() => _editedAvatar = bytes);
      }
    } finally {
      if (mounted) setState(() => _editingAvatar = false);
    }
  }

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

  String _formatCheckedAt(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'недавно';
    String two(int n) => n.toString().padLeft(2, '0');
    return two(date.day) + '.' + two(date.month) + '.' +
        date.year.toString() + ', ' +
        two(date.hour) + ':' + two(date.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = CommunityAvatar.colorsFor(community.iconKind).first;

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сообщество',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.canEditAvatar && !community.isPending)
            IconButton(
              onPressed: _editInfo,
              tooltip: 'Редактировать информацию',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: widget.canEditAvatar &&
                                      widget.onEditAvatar != null
                                  ? _changeAvatar
                                  : null,
                              child: CommunityAvatar(
                                community: community,
                                size: 74,
                                previewBytes: _editedAvatar,
                              ),
                            ),
                            if (widget.canEditAvatar &&
                                widget.onEditAvatar != null)
                              Positioned(
                                right: -3,
                                bottom: -3,
                                child: Material(
                                  color: theme.colorScheme.primary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _editingAvatar ? null : _changeAvatar,
                                    child: SizedBox(
                                      width: 27,
                                      height: 27,
                                      child: _editingAvatar
                                          ? const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              community.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                community.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (community.isPending) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Ожидает модерации · видно только тебе',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.groups_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Аудитория сообщества',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          community.membersLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (community.memberCountSource == 'manual') ...[
                          const SizedBox(height: 4),
                          Text(
                            'Указано администратором · не проверено автоматически',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ] else if (community.memberCountSource != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Источник: ' +
                                (community.memberCountSource == 'telegram'
                                    ? 'Telegram'
                                    : 'ВКонтакте') +
                                '. Данные обновляются автоматически.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          if (community.memberCountCheckedAt != null)
                            Text(
                              'Проверено: ' +
                                  _formatCheckedAt(community.memberCountCheckedAt!),
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Соцсеть пока не предоставила сведения. '
                            'Попробуй обновить список сообществ позже.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
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
    ));
  }
}
