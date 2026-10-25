import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/core/theme/app_theme.dart';
import '/features/services/cloud/view/cloud_screen.dart';
import '../data/telegram_groups_api.dart';
import '../nfc/view/nfc_pass_screen.dart';
import '../qr/view/qr_scanner_screen.dart';
import '../widgets/widgets.dart';

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

class _TelegramGroup {
  const _TelegramGroup({
    required this.title,
    required this.username,
    required this.subtitle,
  });

  final String title;
  final String username;
  final String subtitle;

  bool matches(String query) =>
      (title + ' ' + username + ' ' + subtitle)
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
  final TelegramGroupsApi _groupsApi = const TelegramGroupsApi();

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
      subtitle: 'Проверка NFC студенческого',
      searchTerms: 'студенческий билет пропуск турникет карта скуд nfc',
      icon: Icons.nfc,
      color: Color(0xFF2DD4BF),
    ),
  ];

  static const _fallbackGroups = <_TelegramGroup>[
    _TelegramGroup(
      title: 'Чат студентов МЭИ',
      username: 'mpeichat',
      subtitle: 'Telegram · общение студентов',
    ),
    _TelegramGroup(
      title: 'Первый курс МЭИ',
      username: 'mpei_1kurs',
      subtitle: 'Telegram · первокурсники',
    ),
    _TelegramGroup(
      title: 'Подслушано МЭИ',
      username: 'MPEImai',
      subtitle: 'Telegram · канал',
    ),
  ];

  late List<_TelegramGroup> _groups = _fallbackGroups;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final fetched = await _groupsApi.getGroups();
      if (!mounted) return;

      setState(() {
        _groups = fetched
            .map((group) => _TelegramGroup(
                  title: group.title,
                  username: group.username,
                  subtitle: group.subtitle,
                ))
            .toList();
      });
    } catch (_) {
      // The service directory must remain usable when the server is offline.
      // The last bundled, curated list remains visible without error prompts.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _openTelegramGroup(_TelegramGroup group) async {
    // Only public, user-specified Telegram usernames are used here.
    final uri = Uri.https('t.me', '/' + group.username);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showOpenError();
    } catch (_) {
      if (mounted) _showOpenError();
    }
  }

  void _showOpenError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось открыть Telegram. Проверьте соединение или ссылку.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final matchedServices = _services
        .where((service) => service.matches(query))
        .toList();
    final matchedGroups = _groups
        .where((group) => group.matches(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сервисы',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Поиск сервисов и групп',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.3,
                  ),
                ),
              ),
            ),
            if (matchedServices.isNotEmpty) ...[
              const SizedBox(height: 29),
              Text(
                'Популярные сервисы',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: matchedServices.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final service = matchedServices[index];
                    return PopularServiceCard(
                      title: service.title,
                      subtitle: service.subtitle,
                      icon: service.icon,
                      iconColor: service.color,
                      onTap: () => _openService(service.type),
                    );
                  },
                ),
              ),
            ],
            if (matchedGroups.isNotEmpty) ...[
              const SizedBox(height: 30),
              Text(
                'Группы',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Сообщества студентов в Telegram',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final group in matchedGroups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TelegramGroupTile(
                    title: group.title,
                    username: group.username,
                    subtitle: group.subtitle,
                    onTap: () => _openTelegramGroup(group),
                  ),
                ),
            ],
            if (matchedServices.isEmpty && matchedGroups.isEmpty) ...[
              const SizedBox(height: 76),
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Ничего не найдено',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Попробуй другой запрос',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TelegramGroupTile extends StatelessWidget {
  const _TelegramGroupTile({
    required this.title,
    required this.username,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String username;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF37B5EC), Color(0xFF229ED9)],
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@' + username,
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
