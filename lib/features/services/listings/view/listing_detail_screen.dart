import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '/core/theme/app_theme.dart';
import '../data/listings_api.dart';
import 'listing_editor_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.onChanged,
  });

  final CampusListing listing;
  final Future<void> Function() onChanged;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late CampusListing _listing;
  bool _busy = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
  }

  Future<void> _refreshOwner() async {
    try {
      await ListingsApi.instance.ensureSession();
      final fresh = await ListingsApi.instance.get(_listing.id);
      if (mounted) setState(() => _listing = fresh);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        error.toString().replaceFirst('Exception: ', ''),
      )),
    );
  }

  Future<void> _openContact() async {
    final uri = Uri.https('t.me', '/' + _listing.telegram);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Не удалось открыть Telegram');
    }
  }

  Future<void> _copyTelegram() async {
    await Clipboard.setData(ClipboardData(text: '@' + _listing.telegram));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram скопирован')),
      );
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    try {
      await ListingsApi.instance.ensureSession();
      final fresh = await ListingsApi.instance.get(_listing.id);
      if (!fresh.isMine) {
        _showError('Редактировать может только автор');
        return;
      }
      if (!mounted) return;
      final changed = await Navigator.of(context).push<CampusListing>(
        MaterialPageRoute(
          builder: (_) => ListingEditorScreen(
            kind: fresh.kind,
            listing: fresh,
          ),
        ),
      );
      if (changed == null || !mounted) return;
      setState(() => _listing = changed);
      await widget.onChanged();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _setClosed(bool close) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await ListingsApi.instance.update(
        _listing.id,
        {'status': close ? 'closed' : 'active'},
      );
      if (!mounted) return;
      setState(() => _listing = updated);
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(close
              ? _listing.kind == 'market'
                  ? 'Товар отмечен как проданный'
                  : 'Объявление закрыто'
              : 'Объявление снова активно')),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (yes != true || _busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await ListingsApi.instance.delete(_listing.id);
      await widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Пожаловаться на объявление',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            for (final row in const [
              ('spam', 'Спам'),
              ('fraud', 'Мошенничество'),
              ('privacy', 'Личные данные'),
              ('other', 'Другая причина'),
            ])
              ListTile(
                title: Text(row.$2),
                onTap: () => Navigator.pop(context, row.$1),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ListingsApi.instance.report(_listing.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Widget _photos(BuildContext context) {
    final theme = Theme.of(context);
    final urls = _listing.photoUrls;
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: AspectRatio(
        aspectRatio: 1.27,
        child: urls.isEmpty
            ? Container(
                color: theme.colorScheme.surfaceContainer,
                child: const Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 70,
                    color: Color(0xFF8290A9),
                  ),
                ),
              )
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (context, index) => Image.network(
                      ListingsApi.instance.imageUri(urls[index]).toString(),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainer,
                        child: const Icon(Icons.broken_image_outlined, size: 60),
                      ),
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xC8000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_photoIndex + 1} / ${urls.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final item = _listing;
    final market = item.kind == 'market';
    final found = item.kind == 'found';

    return Scaffold(
      appBar: AppBar(
        title: Text(market ? 'Объявление' : 'Бюро находок'),
        actions: [
          if (item.isMine)
            IconButton(
              tooltip: 'Редактировать',
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            )
          else
            IconButton(
              tooltip: 'Пожаловаться',
              onPressed: _report,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 120),
          children: [
            _photos(context),
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                Chip(
                  label: Text(
                    market ? item.category : found ? 'Нашли' : 'Ищут',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (item.isClosed)
                  const Chip(
                    label: Text(
                      'Закрыто',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (item.isMine)
                  const Chip(label: Text('Моё объявление')),
              ],
            ),
            const SizedBox(height: 15),
            if (market) ...[
              Text(
                item.priceLabel,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: item.isFree ? const Color(0xFFAFC7FF) : null,
                ),
              ),
              const SizedBox(height: 7),
            ],
            Text(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.authorName + ' · ' + item.ageLabel,
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 25),
            Text(
              'Описание',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.description,
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
            if (item.location?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              _DetailRow(
                icon: Icons.place_outlined,
                name: market ? 'Место встречи' : 'Место',
                value: item.location!,
              ),
            ],
            if (market && item.condition != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.fact_check_outlined,
                name: 'Состояние',
                value: switch (item.condition) {
                  'new' => 'Новое',
                  'good' => 'Хорошее',
                  _ => 'Есть следы использования',
                },
              ),
            ],
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.send_outlined,
              name: 'Telegram',
              value: '@' + item.telegram,
              onTap: _copyTelegram,
            ),
            if (!market) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Если речь о документах, не пересылай незнакомым людям '
                  'их номер или фотографии с персональными данными. '
                  'Проверь, что вещь действительно принадлежит собеседнику.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (item.isMine) ...[
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _setClosed(!item.isClosed),
                icon: Icon(item.isClosed
                    ? Icons.restart_alt_rounded
                    : Icons.check_circle_outline_rounded),
                label: Text(item.isClosed
                    ? 'Опубликовать снова'
                    : market ? 'Отметить как проданное' : 'Вещь возвращена'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить объявление'),
              ),
            ] else ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _refreshOwner,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Обновить данные'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: item.isMine || item.isClosed
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(19, 10, 19, 17),
                child: FilledButton.icon(
                  onPressed: _openContact,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Написать в Telegram'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.name,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String name;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.pink),
      title: Text(name, style: TextStyle(color: muted, fontSize: 12)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      trailing: onTap == null ? null
          : const Icon(Icons.copy_rounded, size: 18),
      onTap: onTap,
    );
  }
}
