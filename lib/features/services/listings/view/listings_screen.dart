import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/core/theme/app_theme.dart';
import '../data/listings_api.dart';
import 'listing_detail_screen.dart';
import 'listing_editor_screen.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key, required this.market});

  final bool market;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _api = ListingsApi.instance;
  final _favoritesStore = ListingFavorites();
  final _search = TextEditingController();

  List<CampusListing> _items = [];
  Set<int> _favorites = {};
  Timer? _debounce;
  bool _loading = true;
  bool _mine = false;
  bool _favoritesOnly = false;
  String? _error;
  String _category = 'Все';
  String _kind = 'all';
  String _sort = 'recent';

  @override
  void initState() {
    super.initState();
    _favoritesStore.load().then((ids) {
      if (mounted) setState(() => _favorites = ids);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _serverKind {
    if (widget.market) return 'market';
    return _kind == 'all' ? 'lost' : _kind;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<CampusListing> fetched;
      if (!widget.market && _kind == 'all') {
        final results = await Future.wait([
          _api.load(
            kind: 'lost',
            query: _search.text,
            category: _category,
            mine: _mine,
          ),
          _api.load(
            kind: 'found',
            query: _search.text,
            category: _category,
            mine: _mine,
          ),
        ]);
        fetched = [...results[0], ...results[1]]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        fetched = await _api.load(
          kind: _serverKind,
          query: _search.text,
          category: _category,
          sort: widget.market ? _sort : 'recent',
          mine: _mine,
        );
      }
      if (!mounted) return;
      setState(() => _items = fetched);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _items = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _setMine() async {
    if (!_mine) {
      try {
        await _api.ensureSession();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          )),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _mine = !_mine);
    _load();
  }

  Future<void> _create() async {
    try {
      await _api.ensureSession();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          error.toString().replaceFirst('Exception: ', ''),
        )),
      );
      return;
    }
    if (!mounted) return;
    final created = await Navigator.of(context).push<CampusListing>(
      MaterialPageRoute(
        builder: (_) => ListingEditorScreen(
          kind: widget.market ? 'market' : 'lost',
          chooseKind: !widget.market,
        ),
      ),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    _openDetail(created);
  }

  void _openDetail(CampusListing listing) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          onChanged: _load,
        ),
      ),
    );
  }

  void _toggleFavorite(int id) {
    setState(() {
      if (!_favorites.add(id)) _favorites.remove(id);
    });
    _favoritesStore.save(_favorites).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить избранное')),
        );
      }
    });
  }

  Future<void> _contact(CampusListing listing) async {
    final uri = Uri.https('t.me', '/' + listing.telegram);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть Telegram')),
      );
    }
  }

  Future<void> _sortMenu() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Сортировка',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            for (final option in const [
              ('recent', 'Сначала новые'),
              ('price_asc', 'Сначала дешёвые'),
              ('price_desc', 'Сначала дорогие'),
            ])
              ListTile(
                title: Text(option.$2),
                leading: Icon(
                  _sort == option.$1
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _sort == option.$1 ? AppTheme.pink : null,
                ),
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == _sort || !mounted) return;
    setState(() => _sort = chosen);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final visibleItems = widget.market && _favoritesOnly
        ? _items.where((item) => _favorites.contains(item.id)).toList()
        : _items;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.market ? 'Маркет' : 'Бюро находок',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: _create,
            tooltip: 'Создать объявление',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFAAC6FF),
              foregroundColor: const Color(0xFF172540),
            ),
            icon: const Icon(Icons.add_rounded, size: 25),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.market)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 9),
                child: _FoundTabs(
                  value: _kind,
                  onChanged: (kind) {
                    setState(() => _kind = kind);
                    _load();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => _searchChanged(),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText: widget.market
                            ? 'Поиск объявлений'
                            : 'Что потеряли или нашли?',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty ? null : IconButton(
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filledTonal(
                    onPressed: _setMine,
                    tooltip: _mine ? 'Все объявления' : 'Мои объявления',
                    icon: Icon(
                      _mine ? Icons.person_rounded : Icons.person_outline_rounded,
                    ),
                  ),
                  if (widget.market) ...[
                    const SizedBox(width: 5),
                    IconButton.filledTonal(
                      onPressed: () => setState(
                        () => _favoritesOnly = !_favoritesOnly,
                      ),
                      tooltip: _favoritesOnly
                          ? 'Все товары'
                          : 'Только избранные',
                      icon: Icon(
                        _favoritesOnly
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _favoritesOnly ? AppTheme.pink : null,
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton.filledTonal(
                      onPressed: _sortMenu,
                      tooltip: 'Сортировка',
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final category in widget.market
                      ? marketCategories : foundCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        showCheckmark: false,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() => _category = category);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(
                          message: _error!,
                          onRetry: _load,
                        )
                      : visibleItems.isEmpty
                          ? _EmptyListings(
                              market: widget.market,
                              onCreate: _create,
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: widget.market
                                  ? GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        18, 9, 18, 45,
                                      ),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        mainAxisExtent: 296,
                                      ),
                                      itemCount: visibleItems.length,
                                      itemBuilder: (context, index) =>
                                          _MarketTile(
                                        listing: visibleItems[index],
                                        favorite: _favorites
                                            .contains(visibleItems[index].id),
                                        onFavorite: () => _toggleFavorite(
                                          visibleItems[index].id,
                                        ),
                                        onTap: () => _openDetail(visibleItems[index]),
                                        onContact: () => _contact(visibleItems[index]),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        18, 9, 18, 45,
                                      ),
                                      itemCount: _items.length,
                                      itemBuilder: (context, index) =>
                                          _FoundTile(
                                        listing: _items[index],
                                        onTap: () => _openDetail(_items[index]),
                                        onContact: () => _contact(_items[index]),
                                      ),
                                    ),
                            ),
            ),
            if (_mine && !_loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Показаны твои объявления',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    super.key,
    required this.listing,
    this.fit = BoxFit.cover,
  });
  final CampusListing listing;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHigh;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, Colors.black.withOpacity(0.09)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 39,
          color: Color(0xFF8390A3),
        ),
      ),
    );
    if (listing.photoUrls.isEmpty) return fallback;
    return Image.network(
      ListingsApi.instance.imageUri(listing.photoUrls.first).toString(),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _MarketTile extends StatelessWidget {
  const _MarketTile({
    required this.listing,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
    required this.onContact,
  });

  final CampusListing listing;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 149,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListingPhoto(listing: listing),
                  if (listing.isClosed)
                    Container(
                      color: Colors.black.withOpacity(0.55),
                      alignment: Alignment.center,
                      child: const Text(
                        'ПРОДАНО',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: IconButton.filled(
                      onPressed: onFavorite,
                      tooltip: favorite
                          ? 'Убрать из избранного'
                          : 'Добавить в избранное',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xCC15171D),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: favorite ? AppTheme.pink : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.priceLabel,
                      maxLines: 1,
                      style: TextStyle(
                        color: listing.isFree
                            ? const Color(0xFFAFC7FF)
                            : theme.colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      listing.authorName + ' · ' + listing.ageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: FilledButton.tonal(
                        onPressed: listing.isClosed ? null : onContact,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: const Text(
                          'Написать',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundTabs extends StatelessWidget {
  const _FoundTabs({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (final option in const [
            ('all', 'Все'), ('found', 'Нашли'), ('lost', 'Ищут'),
          ])
            Expanded(
              child: InkWell(
                onTap: () => onChanged(option.$1),
                borderRadius: BorderRadius.circular(26),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: value == option.$1
                        ? const Color(0xFFAAC6FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: value == option.$1
                          ? const Color(0xFF1B2336)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoundTile extends StatelessWidget {
  const _FoundTile({
    required this.listing,
    required this.onTap,
    required this.onContact,
  });
  final CampusListing listing;
  final VoidCallback onTap;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final found = listing.kind == 'found';

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: ListingPhoto(listing: listing),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: found
                            ? const Color(0xFF1C4038)
                            : const Color(0xFF493322),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        found ? 'Нашли' : 'Ищут',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: found
                              ? const Color(0xFF69D0B4)
                              : const Color(0xFFF6B77D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (listing.location?.isNotEmpty == true)
                          listing.location!,
                        listing.ageLabel,
                        listing.authorName,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: listing.isClosed ? null : onContact,
                tooltip: 'Написать в Telegram',
                icon: const Icon(Icons.send_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  const _EmptyListings({required this.market, required this.onCreate});
  final bool market;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              market
                  ? Icons.storefront_outlined
                  : Icons.search_off_rounded,
              size: 56,
              color: AppTheme.pink,
            ),
            const SizedBox(height: 13),
            Text(
              'Пока нет объявлений',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              market
                  ? 'Продай или отдай ненужную вещь студентам.'
                  : 'Помоги вернуть найденную вещь владельцу.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Создать объявление'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 45),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
