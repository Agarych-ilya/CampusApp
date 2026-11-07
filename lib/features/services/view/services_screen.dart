import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/features/services/cloud/view/cloud_screen.dart';
import '../data/community_api.dart';
import '../data/community_admin_api.dart';
import '../nfc/view/nfc_pass_screen.dart';
import '../qr/view/qr_scanner_screen.dart';
import '../widgets/community_avatar.dart';
import '../widgets/widgets.dart';
import 'add_community_screen.dart';
import 'community_detail_screen.dart';
import 'community_admin_screen.dart';

enum _ServiceType { cloud, qr, nfc }

class _ServiceInfo {
  const _ServiceInfo({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.searchTerms,
    required this.icon,
    required this.color,
  });

  final _ServiceType type;
  final String title;
  final String subtitle;
  final String searchTerms;
  final IconData icon;
  final Color color;

  bool matches(String query) =>
      (title + ' ' + subtitle + ' ' + searchTerms)
          .toLowerCase()
          .contains(query);
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CommunityApi _api = const CommunityApi();
  final PendingCommunityStorage _pendingStorage = PendingCommunityStorage();
  final CommunityCatalogCache _catalogCache = CommunityCatalogCache();

  static const _services = <_ServiceInfo>[
    _ServiceInfo(
      type: _ServiceType.cloud,
      title: 'Cloud Campus',
      subtitle: 'Файлы и материалы',
      searchTerms: 'облако документы хранение учебные',
      icon: Icons.cloud_outlined,
      color: AppTheme.pink,
    ),
    _ServiceInfo(
      type: _ServiceType.qr,
      title: 'QR-сканер',
      subtitle: 'Сканирование QR-кодов',
      searchTerms: 'камера код ссылка qr',
      icon: Icons.qr_code_scanner,
      color: Color(0xFF60A5FA),
    ),
    _ServiceInfo(
      type: _ServiceType.nfc,
      title: 'NFC-пропуск',
      subtitle: 'Сохранение информации о студенческом',
      searchTerms: 'студенческий билет пропуск турникет карта скуд nfc',
      icon: Icons.nfc,
      color: Color(0xFF2DD4BF),
    ),
  ];

  List<CommunityData> _communities = [];
  List<CommunityData> _pending = [];
  bool _offline = false;
  bool _canManageCommunities = false;
  bool _checkingAdmin = false;
  int _activePage = 0;
  late final PageController _pageController;
  String? _deletingCommunityId;
  String? _editingAvatarId;
  final Map<String, Uint8List> _avatarPreviews = {};
  String _activeCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadPending();
    _loadCachedCatalog();
    _loadCommunities();
    _checkExistingBarsAdmin();
  }

  Future<void> _checkExistingBarsAdmin() async {
    if (_checkingAdmin) return;
    _checkingAdmin = true;
    try {
      final allowed = await CommunityAdminApi.instance.ensureBarsAdminSession();
      if (mounted) setState(() => _canManageCommunities = allowed);
    } finally {
      _checkingAdmin = false;
    }
  }

  Future<void> _refreshGroupsAndPermissions() async {
    // Allow recovery if the local backend was started after the app.
    await Future.wait([
      _loadCommunities(),
      _checkExistingBarsAdmin(),
    ]);
  }

  Future<void> _loadCachedCatalog() async {
    final cached = await _catalogCache.read();
    if (!mounted || !_offline && _communities.isNotEmpty) return;
    setState(() => _communities = cached);
  }

  Future<void> _loadPending() async {
    final items = await _pendingStorage.read();
    if (!mounted) return;
    setState(() => _pending = items);
  }

  Future<void> _loadCommunities() async {
    try {
      final groups = await _api.getGroups();
      if (!mounted) return;
      setState(() {
        _communities = groups;
        _offline = false;
      });

      try {
        await _catalogCache.save(groups);
        await _pendingStorage.reconcile(groups);
      } catch (_) {
        // Network data remains valid even if device storage is unavailable.
      }
      await _loadPending();
    } catch (_) {
      final cached = await _catalogCache.read();
      if (mounted) {
        setState(() {
          _offline = true;
          _communities = cached;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _switchPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _activePage = index);
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Widget _serviceGrid(List<_ServiceInfo> services) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 660
            ? 4
            : constraints.maxWidth >= 440 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 172,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return PopularServiceCard(
              title: service.title,
              subtitle: service.subtitle,
              icon: service.icon,
              iconColor: service.color,
              onTap: () => _openService(service.type),
            );
          },
        );
      },
    );
  }

  Widget _communityTile(CommunityData community) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _CommunityTile(
        community: community,
        onTap: () => _openCommunity(community),
        onEditAvatar: _canManageCommunities
            ? () => _editCommunityAvatar(community)
            : null,
        canEditAvatar: _canManageCommunities,
        avatarPreviewBytes: _avatarPreviews[community.id],
        avatarUploading: _editingAvatarId == community.id,
        onDelete: _canManageCommunities
            ? () => _deleteCommunity(community)
            : null,
        deleting: _deletingCommunityId == community.id,
      ),
    );
  }

  void _openService(_ServiceType type) {
    final Widget screen = switch (type) {
      _ServiceType.cloud => const CloudScreen(),
      _ServiceType.qr => const QrScannerScreen(),
      _ServiceType.nfc => const NfcPassScreen(),
    };

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _openCommunity(CommunityData community) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDetailScreen(
          community: community,
          onEditAvatar: _canManageCommunities
              ? () => _editCommunityAvatar(community)
              : null,
          canEditAvatar: _canManageCommunities,
        ),
      ),
    );
  }

  Future<void> _openAdmin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityAdminScreen(),
      ),
    );
    if (!mounted) return;
    // Moderation may publish, reject or remove groups while the panel is open.
    await _loadCommunities();
    await _loadPending();
    await _checkExistingBarsAdmin();
  }

  /// Only verified moderators may replace existing group avatars.
  /// The backend also enforces admin permissions on PATCH .../icon.
  Future<Uint8List?> _editCommunityAvatar(CommunityData community) async {
    if (_editingAvatarId != null || _deletingCommunityId != null) return null;

    setState(() => _editingAvatarId = community.id);
    try {
      // A failed check during initial screen load must never permanently
      // hide editing from an administrator. Retry on explicit avatar tap.
      final admin = CommunityAdminApi.instance;
      final isAdmin = await admin.ensureBarsAdminSession();
      if (!mounted) return null;
      setState(() => _canManageCommunities = isAdmin);
      if (!isAdmin) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Редактирование недоступно'),
            content: Text(
              'Сервер не подтвердил права администратора.\n\n'
              '${admin.lastBarsAuthError ?? "Проверь подключение к бэкенду и действующую сессию БАРС."}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
        return null;
      }

      final selected = await FilePicker.pickFile(type: FileType.image);
      if (selected == null) return null;

      final length = await selected.length();
      if (length != null && length > 15 * 1024 * 1024) {
        throw const FormatException('Выбери изображение размером до 15 МБ.');
      }
      final rawBytes = await selected.readAsBytes();
      if (rawBytes.length > 15 * 1024 * 1024) {
        throw const FormatException('Выбери изображение размером до 15 МБ.');
      }

      // Same 400x400 center crop used when adding new communities.
      final processed = await prepareCommunityIcon(rawBytes);
      if (processed.length < 12 || processed.length > 700 * 1024) {
        throw const FormatException(
          'После обработки фотография должна занимать не более 700 КБ.',
        );
      }

      if (!mounted) return null;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Заменить аватарку?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  processed,
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Новая аватарка для «' + community.title + '». '
                'Изменение будет видно всем студентам.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return null;

      // Require fresh proof again before upload. The backend independently
      // validates the moderator session and CSRF token on every PATCH.
      if (!await admin.ensureBarsAdminSession()) {
        if (mounted) setState(() => _canManageCommunities = false);
        throw Exception(
          admin.lastBarsAuthError ??
          'Не удалось подтвердить права администратора через БАРС.',
        );
      }

      final pending = RegExp(r'^pending-([1-9][0-9]*)$')
          .firstMatch(community.id);
      final serverId = pending == null
          ? community.id
          : 'community-' + pending.group(1)!;

      await admin.updateIcon(serverId, processed);

      // Keep pending thumbnails in sync on the submitting device.
      if (pending != null) {
        try {
          await _pendingStorage.saveIcon(
            int.parse(pending.group(1)!),
            processed,
            'png',
          );
          await _loadPending();
        } catch (_) {
          // Successful server save must not be reported as a failure.
        }
      }

      if (!mounted) return null;
      // Instant visual refresh, regardless of the network image cache.
      setState(() => _avatarPreviews[community.id] = processed);
      await _loadCommunities();
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аватарка сообщества обновлена')),
      );
      return processed;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString()
                  .replaceFirst('Exception: ', '')
                  .replaceFirst('FormatException: ', ''),
            ),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _editingAvatarId = null);
    }
  }

  Future<void> _deleteCommunity(CommunityData community) async {
    if (_deletingCommunityId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сообщество?'),
        content: Text(
          '«${community.title}» будет удалено из каталога. '
          'Встроенные сообщества можно восстановить в управлении группами.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingCommunityId = community.id);
    try {
      final admin = CommunityAdminApi.instance;
      if (!await admin.ensureBarsAdminSession()) {
        throw Exception(
          admin.lastBarsAuthError ??
          'Не удалось подтвердить права. Проверь подключение к бэкенду '
          'и обнови список групп.',
        );
      }
      final pendingMatch = RegExp(r'^pending-([1-9][0-9]*)$')
          .firstMatch(community.id);
      final targetId = pendingMatch == null
          ? community.id
          : 'community-${pendingMatch.group(1)}';
      await admin.delete(targetId);
      _avatarPreviews.remove(community.id);
      if (pendingMatch != null) {
        await _pendingStorage.removeById(community.id);
        await _loadPending();
      } else {
        // Remove it from the offline catalog after the server confirms
        // deletion, so a temporary outage cannot resurrect the old entry.
        if (mounted) {
          setState(() {
            _communities = _communities
                .where((item) => item.id != community.id)
                .toList();
          });
        }
        try {
          await _catalogCache.save(_communities);
        } catch (_) {
          // Successful server deletion takes priority over local caching.
        }
      }
      await _loadCommunities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщество удалено из каталога')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _canManageCommunities = CommunityAdminApi.instance.isSignedIn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingCommunityId = null);
    }
  }

  Future<void> _addCommunity() async {
    final result = await Navigator.of(context).push<CommunityData>(
      MaterialPageRoute<CommunityData>(
        builder: (_) => const AddCommunityScreen(),
      ),
    );

    if (!mounted || result == null) return;

    if (!result.isPending) {
      await _loadCommunities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщество опубликовано')),
      );
      return;
    }

    setState(() {
      _pending = [
        result,
        ..._pending.where((item) => item.id != result.id),
      ];
      _activeCategory = 'Все';
    });

    _searchController.clear();
    await _loadPending();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Сообщество добавлено в твои заявки и отправлено на проверку.',
        ),
      ),
    );
  }

  List<CommunityData> get _allCommunities {
    final approvedLinks = _communities
        .expand((community) => [
              community.telegramUrl?.toLowerCase(),
              community.vkUrl?.toLowerCase(),
            ])
        .whereType<String>()
        .toSet();

    final unapproved = _pending.where((community) {
      return ![
        community.telegramUrl?.toLowerCase(),
        community.vkUrl?.toLowerCase(),
      ].whereType<String>().any(approvedLinks.contains);
    });

    return [...unapproved, ..._communities];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final matchedServices = _services
        .where((service) => service.matches(query))
        .toList();

    final all = _allCommunities;
    final availableCategories = <String>[
      'Все',
      ...communityCategories.where(
        (category) => all.any((group) => group.category == category),
      ),
    ];

    final matchedCommunities = all.where((community) {
      return community.matches(query) &&
          (_activeCategory == 'Все' ||
              community.category == _activeCategory);
    }).toList();

    // One global search; the group-only category filter does not hide hits.
    final searchCommunities = all
        .where((community) => community.matches(query))
        .toList();
    final searchResultCount =
        matchedServices.length + searchCommunities.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сервисы',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Поиск сервисов и групп',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: query.isNotEmpty
                        ? AppTheme.pink
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.65,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppTheme.pink,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            if (query.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ServicesPagerTabs(
                  selectedPage: _activePage,
                  onSelected: _switchPage,
                ),
              ),
            Expanded(
              child: query.isNotEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshGroupsAndPermissions,
                      child: ListView(
                        key: const ValueKey('services_groups_global_search'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Результаты поиска',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Найдено: $searchResultCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (matchedServices.isNotEmpty) ...[
                            _CatalogSectionTitle(
                              title: 'Сервисы',
                              count: matchedServices.length,
                              icon: Icons.apps_rounded,
                            ),
                            const SizedBox(height: 14),
                            _serviceGrid(matchedServices),
                            const SizedBox(height: 26),
                          ],
                          if (searchCommunities.isNotEmpty) ...[
                            _CatalogSectionTitle(
                              title: 'Группы и сообщества',
                              count: searchCommunities.length,
                              icon: Icons.groups_2_rounded,
                            ),
                            const SizedBox(height: 14),
                            for (final community in searchCommunities)
                              _communityTile(community),
                          ],
                          if (searchResultCount == 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 38, 16, 0),
                              child: Column(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.manage_search_rounded,
                                      size: 34,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Ничего не найдено',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    'Попробуй название, ключевое слово или категорию.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: _clearSearch,
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Сбросить поиск'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      children: [
                        RefreshIndicator(
                          onRefresh: _refreshGroupsAndPermissions,
                          child: ListView(
                            key: const PageStorageKey('catalog_services'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                            children: [
                              _CatalogSectionTitle(
                                title: 'Сервисы кампуса',
                                count: _services.length,
                                icon: Icons.apps_rounded,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Полезные инструменты всегда под рукой',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _serviceGrid(_services),
                            ],
                          ),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshGroupsAndPermissions,
                          child: ListView(
                            key: const PageStorageKey('catalog_groups'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Группы',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Сообщества студентов МЭИ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_canManageCommunities) ...[
                    IconButton(
                      onPressed: _openAdmin,
                      tooltip: 'Управление сообществами',
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                    ),
                    const SizedBox(width: 5),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _addCommunity,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text(
                      'Добавить',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in availableCategories)
                    ChoiceChip(
                      label: Text(category),
                      selected: _activeCategory == category,
                      onSelected: (_) => setState(
                        () => _activeCategory = category,
                      ),
                    ),
                ],
              ),
              if (_offline) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Color(0xFFFFB76E),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Сервер недоступен. Показан последний сохранённый каталог.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 15),
              if (matchedCommunities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 42,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Сообщества не найдены',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Попробуй другой запрос или добавь своё.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final community in matchedCommunities)
                  _communityTile(community),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ServicesPagerTabs extends StatelessWidget {
  const _ServicesPagerTabs({
    required this.selectedPage,
    required this.onSelected,
  });

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.onSurface;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    Widget tab(int index, String label) {
      final selected = selectedPage == index;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.9,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? activeColor : inactiveColor,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: selected ? 68 : 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          tab(0, 'СЕРВИСЫ'),
          tab(1, 'ГРУППЫ'),
        ],
      ),
    );
  }
}

class _CatalogSectionTitle extends StatelessWidget {
  const _CatalogSectionTitle({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppTheme.pink.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppTheme.pink, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.community,
    required this.onTap,
    this.onDelete,
    this.onEditAvatar,
    this.canEditAvatar = false,
    this.avatarPreviewBytes,
    this.avatarUploading = false,
    this.deleting = false,
  });

  final CommunityData community;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEditAvatar;
  final bool canEditAvatar;
  final Uint8List? avatarPreviewBytes;
  final bool avatarUploading;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canEditAvatar ? onEditAvatar : null,
                      child: CommunityAvatar(
                        community: community,
                        size: 60,
                        previewBytes: avatarPreviewBytes,
                      ),
                    ),
                    if (canEditAvatar && onEditAvatar != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: theme.colorScheme.primary,
                          shape: const CircleBorder(),
                          child: Tooltip(
                            message: 'Изменить аватарку',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: avatarUploading ? null : onEditAvatar,
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: avatarUploading
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.camera_alt_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 9,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 14,
                              color: muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              community.memberCount == null
                                  ? 'Нет данных об участниках'
                                  : community.membersLabel,
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (community.telegramUrl != null)
                          const _SocialMiniLabel(
                            label: 'TG',
                            color: Color(0xFF229ED9),
                          ),
                        if (community.vkUrl != null)
                          const _SocialMiniLabel(
                            label: 'VK',
                            color: Color(0xFF0077FF),
                          ),
                        if (community.isPending)
                          const _SocialMiniLabel(
                            label: 'На проверке',
                            color: Color(0xFFF0B45A),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: deleting ? null : onDelete,
                  tooltip: 'Удалить сообщество',
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 21),
                ),
              if (onDelete == null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialMiniLabel extends StatelessWidget {
  const _SocialMiniLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
