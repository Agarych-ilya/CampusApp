import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/community_api.dart';
import '../widgets/community_avatar.dart';

class AddCommunityScreen extends StatefulWidget {
  const AddCommunityScreen({super.key});

  @override
  State<AddCommunityScreen> createState() => _AddCommunityScreenState();
}

class _AddCommunityScreenState extends State<AddCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = const CommunityApi();
  final _pendingStorage = PendingCommunityStorage();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _membersController = TextEditingController();
  final _telegramController = TextEditingController();
  final _vkController = TextEditingController();

  String _category = communityCategories.first;
  String _iconKind = communityIconKinds.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _membersController.dispose();
    _telegramController.dispose();
    _vkController.dispose();
    super.dispose();
  }

  String? _normalizeSocial(String raw, String host) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('@')) text = text.substring(1);

    if (!text.contains('/') && !text.contains(':')) {
      text = 'https://' + host + '/' + text;
    } else if (text.startsWith(host + '/')) {
      text = 'https://' + text;
    }

    return text;
  }

  String? _validateSocial(String? raw, String host) {
    final link = _normalizeSocial(raw ?? '', host);
    if (link == null) return null;

    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.scheme != 'https' ||
        ![host, 'www.' + host].contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.where((part) => part.isNotEmpty).isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_+./-]{1,120}$')
            .hasMatch(uri.path.replaceFirst(RegExp(r'^/'), ''))) {
      return 'Укажи ссылку https://' + host + '/...';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    final telegram = _normalizeSocial(_telegramController.text, 't.me');
    final vk = _normalizeSocial(_vkController.text, 'vk.com');

    if (telegram == null && vk == null) {
      setState(() {
        _error = 'Добавь хотя бы одну ссылку: Telegram или ВКонтакте.';
      });
      return;
    }

    final rawCount = _membersController.text.trim();
    final draft = CommunityDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      iconKind: _iconKind,
      memberCount: rawCount.isEmpty ? null : int.tryParse(rawCount),
      telegramUrl: telegram,
      vkUrl: vk,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final id = await _api.submit(draft);
      final pending = draft.asPending(id);

      // The backend has accepted the submission even when local caching fails.
      try {
        await _pendingStorage.save(pending);
      } catch (_) {
        // Reopen this screen from the same device to submit a new group.
      }

      if (!mounted) return;
      Navigator.of(context).pop(pending);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final example = CommunityData(
      id: 'preview',
      title: _titleController.text.trim().isEmpty
          ? 'Моё сообщество'
          : _titleController.text.trim(),
      subtitle: _category,
      description: '',
      category: _category,
      iconKind: _iconKind,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Добавить сообщество',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CommunityAvatar(community: example, size: 72),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Твоё сообщество',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Добавь информацию. После проверки '
                            'оно появится у всех студентов.',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(label: 'Основная информация'),
              const SizedBox(height: 13),
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название сообщества',
                  hintText: 'Например, Робототехника МЭИ',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 3) {
                    return 'Название должно содержать минимум 3 символа';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'О чём ваше сообщество и кому оно будет полезно?',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 15) {
                    return 'Добавь описание хотя бы из 15 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in communityCategories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              const SizedBox(height: 23),
              _SectionTitle(label: 'Иконка сообщества'),
              const SizedBox(height: 8),
              Text(
                'Выбери подходящий стиль. Его увидят все студенты.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 11,
                runSpacing: 12,
                children: [
                  for (final icon in communityIconKinds)
                    _IconOption(
                      iconKind: icon,
                      selected: _iconKind == icon,
                      onTap: _submitting
                          ? null
                          : () => setState(() => _iconKind = icon),
                    ),
                ],
              ),
              const SizedBox(height: 25),
              _SectionTitle(label: 'Участники'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _membersController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Примерное число участников',
                  hintText: 'Необязательно',
                  prefixIcon: Icon(Icons.people_alt_outlined),
                ),
                validator: (value) {
                  final raw = (value ?? '').trim();
                  if (raw.isEmpty) return null;
                  final parsed = int.tryParse(raw);
                  if (parsed == null || parsed < 1 || parsed > 100000000) {
                    return 'Укажи число от 1 до 100 000 000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Указанное число будет помечено «по данным автора». '
                'CampusApp не считывает участников из Telegram или VK.',
                style: TextStyle(fontSize: 11, color: muted, height: 1.45),
              ),
              const SizedBox(height: 25),
              _SectionTitle(label: 'Ссылки на соцсети'),
              const SizedBox(height: 8),
              Text(
                'Заполни хотя бы одну ссылку. Допускается @username '
                'или полный адрес страницы.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telegramController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  hintText: 'https://t.me/my_community',
                  prefixIcon: Icon(Icons.send_rounded),
                ),
                validator: (value) => _validateSocial(value, 't.me'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _vkController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'ВКонтакте',
                  hintText: 'https://vk.com/my_community',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                validator: (value) => _validateSocial(value, 'vk.com'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF808D),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    _submitting
                        ? 'Отправляем…'
                        : 'Отправить на проверку',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Заявки публикуются только после проверки модератором. '
                'До этого твоё сообщество будет видно здесь с пометкой '
                '«На проверке».',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
    ),
  );
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconKind,
    required this.selected,
    required this.onTap,
  });

  final String iconKind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CommunityAvatar.colorsFor(iconKind);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 91,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? colors.first.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          children: [
            Icon(
              CommunityAvatar.iconFor(iconKind),
              color: colors.first,
              size: 26,
            ),
            const SizedBox(height: 7),
            Text(
              switch (iconKind) {
                'chat' => 'Чат',
                'campus' => 'Кампус',
                'news' => 'Новости',
                'study' => 'Учёба',
                'club' => 'Клуб',
                'events' => 'События',
                _ => 'Группа',
              },
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? colors.first : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
