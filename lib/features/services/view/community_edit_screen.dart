import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';

import '../data/community_admin_api.dart';
import '../data/community_api.dart';

/// Editing is exposed only after verified administrator authentication.
/// The backend independently verifies the session and CSRF token.
class CommunityEditScreen extends StatefulWidget {
  const CommunityEditScreen({super.key, required this.community});

  final CommunityData community;

  @override
  State<CommunityEditScreen> createState() => _CommunityEditScreenState();
}

class _CommunityEditScreenState extends State<CommunityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _telegram;
  late final TextEditingController _vk;
  late final TextEditingController _memberCount;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final group = widget.community;
    _description = TextEditingController(text: group.description);
    _telegram = TextEditingController(text: group.telegramUrl ?? '');
    _vk = TextEditingController(text: group.vkUrl ?? '');
    _memberCount = TextEditingController(
      text: group.memberCountSource == 'manual'
          ? (group.memberCount?.toString() ?? '')
          : '',
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _telegram.dispose();
    _vk.dispose();
    _memberCount.dispose();
    super.dispose();
  }

  String? _validateLink(String? value, String host) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = Uri.tryParse(text);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        ![host, 'www.' + host].contains(parsed.host.toLowerCase()) ||
        parsed.hasPort ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !RegExp(r'^/[a-zA-Z0-9_.+-]{1,100}/?$').hasMatch(parsed.path)) {
      return 'Укажи корректную ссылку https://' + host + '/...';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_telegram.text.trim().isEmpty && _vk.text.trim().isEmpty) {
      setState(() => _error = 'Оставь хотя бы одну ссылку на сообщество');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = CommunityAdminApi.instance;
      if (!await api.ensureBarsAdminSession()) {
        throw Exception(
          api.lastBarsAuthError ?? 'Нет подтверждённых прав администратора',
        );
      }

      final manualText = _memberCount.text.trim();
      await api.update(
        widget.community.id,
        title: widget.community.title,
        description: _description.text.trim(),
        category: widget.community.category,
        iconKind: widget.community.iconKind,
        telegramUrl: _telegram.text.trim(),
        vkUrl: _vk.text.trim(),
        updateMemberCount: true,
        memberCount: manualText.isEmpty ? null : int.parse(manualText),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    final current = widget.community;

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text(
          'Редактировать сообщество',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Text(
                current.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Изменения будут видны всем студентам после сохранения.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 26),
              Text(
                'О сообществе',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 5,
                minLines: 3,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final length = (value ?? '').trim().length;
                  return length < 15 || length > 1200
                      ? 'Описание: от 15 до 1200 символов'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Социальные сети',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telegram,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  hintText: 'https://t.me/...',
                  prefixIcon: Icon(Icons.send_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateLink(value, 't.me'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vk,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'ВКонтакте',
                  hintText: 'https://vk.com/...',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateLink(value, 'vk.com'),
              ),
              const SizedBox(height: 25),
              Text(
                'Количество участников',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _memberCount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Указать вручную (необязательно)',
                  hintText: 'Автоматические данные',
                  border: const OutlineInputBorder(),
                  helperText: current.memberCountSource == 'manual'
                      ? 'Оставь пустым, чтобы удалить ручное значение.'
                      : 'Пустое поле — использовать сведения Telegram/VK.',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final n = int.tryParse(text);
                  if (n == null || n < 0 || n > 100000000) {
                    return 'Введи целое число от 0 до 100 000 000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: muted, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ручное число будет отмечено как «Указано администратором», '
                      'а не как статистика, проверенная соцсетью.',
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 17),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Сохранение...' : 'Сохранить изменения'),
          ),
        ),
      ),
    ));
  }
}
