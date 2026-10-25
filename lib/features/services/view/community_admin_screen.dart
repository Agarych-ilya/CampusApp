import 'package:flutter/material.dart';

import '../data/community_admin_api.dart';
import '../data/community_api.dart';
import '../widgets/community_avatar.dart';

class CommunityAdminScreen extends StatefulWidget {
  const CommunityAdminScreen({super.key});

  @override
  State<CommunityAdminScreen> createState() => _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends State<CommunityAdminScreen> {
  final _api = CommunityAdminApi.instance;
  final _pendingStorage = PendingCommunityStorage();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _signedIn = false;
  String _filter = 'pending';
  String? _error;
  List<CommunityAdminItem> _items = [];

  @override
  void initState() {
    super.initState();
    if (_api.isSignedIn) {
      _signedIn = true;
      _refresh();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || _email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _api.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      if (!mounted) return;
      setState(() => _signedIn = true);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.getGroups();
      if (!mounted) return;
      setState(() {
        _items = data;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!_api.isSignedIn) setState(() => _signedIn = false);
      setState(() => _error = _message(error));
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _items = [];
      _error = null;
      _password.clear();
    });
  }

  Future<bool> _ask(
    String title,
    String description,
    String action,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  int? _numericId(CommunityAdminItem item) {
    final match = RegExp(r'^community-([1-9]\d*)$')
        .firstMatch(item.community.id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> _review(CommunityAdminItem item, bool approve) async {
    final id = _numericId(item);
    if (id == null) return;

    final confirmed = await _ask(
      approve ? 'Опубликовать сообщество?' : 'Отклонить заявку?',
      '«' + item.community.title + '» ' +
          (approve
              ? 'станет доступно всем студентам.'
              : 'не появится в публичном каталоге.'),
      approve ? 'Подтвердить' : 'Отклонить',
    );
    if (!confirmed || !mounted) return;

    await _runMutation(() async {
      await _api.review(id, approve);
      await _pendingStorage.removeById('pending-' + id.toString());
    });
  }

  Future<void> _delete(CommunityAdminItem item) async {
    final confirmed = await _ask(
      item.builtIn ? 'Скрыть встроенную группу?' : 'Удалить сообщество?',
      item.builtIn
          ? '«' + item.community.title +
              '» исчезнет из каталога. Её можно вернуть через раздел «Скрытые».'
          : '«' + item.community.title +
              '» и загруженная иконка будут удалены с сервера.',
      item.builtIn ? 'Скрыть' : 'Удалить',
    );
    if (!confirmed || !mounted) return;

    await _runMutation(() async {
      await _api.delete(item.community.id);
      final id = _numericId(item);
      if (id != null) {
        await _pendingStorage.removeById('pending-' + id.toString());
      }
    });
  }

  Future<void> _restore(CommunityAdminItem item) async {
    await _runMutation(() => _api.restore(item.community.id));
  }

  Future<void> _edit(CommunityAdminItem item) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _CommunityAdminEditScreen(item: item),
      ),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _runMutation(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Управление группами',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_signedIn)
            IconButton(
              onPressed: _busy ? null : _logout,
              tooltip: 'Выйти из админ-панели',
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: !_signedIn
            ? ListView(
                padding: const EdgeInsets.fromLTRB(22, 32, 22, 32),
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 62,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'Вход администратора',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Нужен аккаунт бэкенда, которому сервер выдал '
                    'права управления сообществами. Вход через БАРС '
                    'не предоставляет эти права.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email администратора',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _login,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Войти'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF808D)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
                  children: [
                    Text(
                      'Модерация сообществ',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Проверяй заявки, редактируй информацию и '
                      'управляй публикацией.',
                      style: TextStyle(color: muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final item in const [
                            ('pending', 'На проверке'),
                            ('approved', 'Опубликованы'),
                            ('rejected', 'Отклонены'),
                            ('hidden', 'Скрытые'),
                            ('all', 'Все'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 9),
                              child: ChoiceChip(
                                label: Text(item.$2),
                                selected: _filter == item.$1,
                                onSelected: (_) =>
                                    setState(() => _filter = item.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 13),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFF808D)),
                        ),
                      ),
                    const SizedBox(height: 15),
                    ..._buildItems(theme),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildItems(ThemeData theme) {
    final visible = _items.where(
      (entry) => _filter == 'all' || entry.status == _filter,
    ).toList();

    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 38),
          child: Center(
            child: Text(
              'Здесь пока нет сообществ',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ];
    }

    return [
      for (final item in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AdminCommunityCard(
            item: item,
            busy: _busy,
            headers: _api.imageHeaders,
            onApprove: item.isPending ? () => _review(item, true) : null,
            onReject: item.isPending ? () => _review(item, false) : null,
            onEdit: () => _edit(item),
            onDelete: () => _delete(item),
            onRestore: item.isHidden ? () => _restore(item) : null,
          ),
        ),
    ];
  }
}

class _AdminCommunityCard extends StatelessWidget {
  const _AdminCommunityCard({
    required this.item,
    required this.busy,
    required this.headers,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final CommunityAdminItem item;
  final bool busy;
  final Map<String, String> headers;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainer,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CommunityAvatar(
                community: item.community,
                imageHeaders: headers,
                size: 55,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.community.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.community.category + ' · ' +
                          switch (item.status) {
                            'pending' => 'На проверке',
                            'approved' => 'Опубликовано',
                            'rejected' => 'Отклонено',
                            'hidden' => 'Скрыто',
                            _ => item.status,
                          },
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            item.community.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onApprove != null)
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Подтвердить'),
                ),
              if (onReject != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Отклонить'),
                ),
              if (onRestore != null)
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Вернуть'),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Изменить'),
              ),
              TextButton.icon(
                onPressed: busy || item.isHidden ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(item.builtIn ? 'Скрыть' : 'Удалить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityAdminEditScreen extends StatefulWidget {
  const _CommunityAdminEditScreen({required this.item});

  final CommunityAdminItem item;

  @override
  State<_CommunityAdminEditScreen> createState() =>
      _CommunityAdminEditScreenState();
}

class _CommunityAdminEditScreenState extends State<_CommunityAdminEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _telegram;
  late final TextEditingController _vk;
  late String _category;
  late String _iconKind;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item.community;
    _title = TextEditingController(text: item.title);
    _description = TextEditingController(text: item.description);
    _telegram = TextEditingController(text: item.telegramUrl ?? '');
    _vk = TextEditingController(text: item.vkUrl ?? '');
    _category = communityCategories.contains(item.category)
        ? item.category : communityCategories.last;
    _iconKind = communityIconKinds.contains(item.iconKind)
        ? item.iconKind : communityIconKinds.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _telegram.dispose();
    _vk.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CommunityAdminApi.instance.update(
        widget.item.community.id,
        title: _title.text,
        description: _description.text,
        category: _category,
        iconKind: _iconKind,
        telegramUrl: _telegram.text,
        vkUrl: _vk.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать сообщество')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (value) => (value ?? '').trim().length < 3
                    ? 'Минимум 3 символа' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLength: 1200,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Описание'),
                validator: (value) => (value ?? '').trim().length < 15
                    ? 'Минимум 15 символов' : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  for (final category in communityCategories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _iconKind,
                decoration: const InputDecoration(
                  labelText: 'Резервная иконка',
                ),
                items: [
                  for (final kind in communityIconKinds)
                    DropdownMenuItem(value: kind, child: Text(kind)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _iconKind = value);
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _telegram,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  hintText: 'https://t.me/example',
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _vk,
                decoration: const InputDecoration(
                  labelText: 'ВКонтакте',
                  hintText: 'https://vk.com/example',
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Исходная фотография сообщества сохраняется. '
                'Здесь можно поменять текст, ссылки, категорию и '
                'резервный значок.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF808D)),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Сохраняем…' : 'Сохранить изменения'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
