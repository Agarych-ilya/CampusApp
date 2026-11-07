import 'dart:async';

import 'package:flutter/material.dart';

import '/features/profile/data/student_profile_storage.dart';

import '/features/services/style/service_palette.dart';

import '../data/study_deck.dart';
import '../data/public_study_api.dart';
import 'study_public_deck_screen.dart';
import '../data/study_activity_storage.dart';
import '../widgets/study_activity_heatmap.dart';
import 'study_editor_screen.dart';
import 'study_session_screen.dart';

class StudyHomeScreen extends StatefulWidget {
  const StudyHomeScreen({super.key});

  @override
  State<StudyHomeScreen> createState() => _StudyHomeScreenState();
}

class _StudyHomeScreenState extends State<StudyHomeScreen> {
  final _store = StudyDeckStore();
  final _activityStore = StudyActivityStorage();
  final _publicApi = PublicStudyApi.instance;
  final _publicDecks = <PublicStudyDeck>[];
  Timer? _searchTimer;
  bool _publicLoading = true;
  String? _publicError;
  int _searchGeneration = 0;
  String _filter = 'all';
  late Future<Map<DateTime, StudyDayActivity>> _activityFuture;
  final _search = TextEditingController();
  List<StudyDeck> _decks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activityFuture = _activityStore.loadByDay();
    _load();
    _loadPublic();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final decks = await _store.load();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось прочитать сохранённые наборы.';
      });
    }
  }

  Future<void> _loadPublic() async {
    final generation = ++_searchGeneration;
    if (mounted) setState(() => _publicLoading = true);
    try {
      final results = await _publicApi.search(
        query: _search.text.trim(),
        sort: _filter == 'popular' ? 'popular' : 'recent',
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _publicDecks
          ..clear()
          ..addAll(results);
        _publicLoading = false;
        _publicError = null;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _publicLoading = false;
        _publicError = 'Не удалось загрузить общие наборы.';
      });
    }
  }

  void _searchChanged(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      _loadPublic,
    );
  }

  void _chooseFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    if (value != 'mine') _loadPublic();
  }

  Future<void> _publishDeck(StudyDeck deck) async {
    final profile = await StudentProfileStorage().getProfile();
    if (!mounted) return;
    final full = profile?.fullName.trim() ?? '';
    final parts = full.split(RegExp(r'\s+'));
    final defaultName = parts.length > 1
        ? '${parts.first} ${parts[1][0]}.'
        : (full.isEmpty ? 'Студент МЭИ' : full);
    var authorName = defaultName;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Опубликовать набор'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Карточки станут доступны всем студентам. '
              'Публикуются только название, описание, термины, '
              'определения и указанное имя автора.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: defaultName,
              maxLength: 60,
              onChanged: (value) => authorName = value,
              decoration: const InputDecoration(labelText: 'Имя автора'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = authorName.trim();
              if (value.length >= 2 && value.length <= 60) {
                Navigator.pop(dialog, value);
              }
            },
            child: const Text('Опубликовать'),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    await _publicApi.publish(deck, authorName: chosen);
    await _loadPublic();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Набор опубликован или обновлён для всех студентов'),
      ),
    );
  }

  Future<void> _openPublicDeck(PublicStudyDeck deck) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudyPublicDeckScreen(
          preview: deck,
          onSaveCopy: (copy) =>
              _savePublicCopy(copy, publicDeckId: deck.id),
          alreadySaved: _store.containsPublicDeck(_decks, deck.id),
          onChanged: _loadPublic,
        ),
      ),
    );
    if (mounted) {
      setState(() => _activityFuture = _activityStore.loadByDay());
      _loadPublic();
    }
  }

  Future<void> _savePublicCopy(
    StudyDeck copy, {
    required int publicDeckId,
  }) async {
    final saved = await _store.savePublicDeckOnce(
      copy,
      publicDeckId: publicDeckId,
    );
    if (mounted) setState(() => _decks = saved);
  }

  Future<void> _saveDeck(StudyDeck deck) async {
    final next = List<StudyDeck>.of(_decks);
    final index = next.indexWhere((item) => item.id == deck.id);
    if (index < 0) {
      next.insert(0, deck);
    } else {
      next[index] = deck;
    }
    await _store.save(next);
    if (mounted) setState(() => _decks = next);
  }

  Future<void> _deleteDeck(StudyDeck deck) async {
    final next = _decks.where((item) => item.id != deck.id).toList();
    await _store.save(next);
    if (mounted) setState(() => _decks = next);
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось сохранить набор на телефоне')),
    );
  }

  Future<void> _create() async {
    final deck = await Navigator.of(context).push<StudyDeck>(
      MaterialPageRoute(builder: (_) => const StudyEditorScreen()),
    );
    if (deck == null || !mounted) return;
    try {
      await _saveDeck(deck);
      if (mounted) _openDeck(deck);
    } catch (_) {
      _showError();
    }
  }

  Future<void> _openDeck(StudyDeck deck) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudyDeckScreen(
          deck: deck,
          onSaved: _saveDeck,
          onDelete: _deleteDeck,
          onPublish: _publishDeck,
        ),
      ),
    );
    if (mounted) {
      setState(() => _activityFuture = _activityStore.loadByDay());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    final query = _search.text.trim().toLowerCase();
    final decks = _decks.where((deck) {
      final content = [
        deck.title,
        deck.description,
        ...deck.cards.expand((card) => [card.term, card.definition]),
      ].join(' ').toLowerCase();
      return content.contains(query);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final showLocal = _filter == 'all' || _filter == 'mine';
    final showPublic = _filter != 'mine';
    final totalCards = _decks.fold<int>(
      0, (total, deck) => total + deck.cards.length,
    );
    final known = _decks.fold<int>(
      0, (total, deck) => total + deck.learnedCount,
    );

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campus Cards',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 42),
                          const SizedBox(height: 14),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 9, 20, 35),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ServicePalette.headerStart,
                              ServicePalette.headerEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 43,
                              width: 43,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.style_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Учись в своём ритме',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 23,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Создавай карточки, повторяй термины '
                              'и проверяй себя перед зачётом.',
                              style: TextStyle(
                                color: ServicePalette.headerSubtitle,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _create,
                              style: FilledButton.styleFrom(
                                backgroundColor: ServicePalette.accent,
                                foregroundColor: ServicePalette.accentOnDark,
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Создать набор'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          Expanded(
                            child: _StudyStat(
                              icon: Icons.auto_stories_outlined,
                              value: _decks.length.toString(),
                              label: 'Наборов',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StudyStat(
                              icon: Icons.layers_outlined,
                              value: totalCards.toString(),
                              label: 'Карточек',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StudyStat(
                              icon: Icons.check_circle_outline_rounded,
                              value: known.toString(),
                              label: 'Выучено',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<Map<DateTime, StudyDayActivity>>(
                        future: _activityFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Row(
                              children: [
                                const Expanded(
                                  child: Text('История тестов недоступна'),
                                ),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _activityFuture =
                                        _activityStore.loadByDay(),
                                  ),
                                  child: const Text('Повторить'),
                                ),
                              ],
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return StudyActivityHeatmap(
                            activity: snapshot.data!,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Наборы для учёбы',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        onChanged: _searchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Поиск наборов, терминов и авторов',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Очистить',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    _searchChanged('');
                                  },
                                ),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final option in const [
                              ('all', 'Все'),
                              ('mine', 'Мои'),
                              ('popular', 'Популярные'),
                              ('new', 'Новые'),
                            ]) ...[
                              ChoiceChip(
                                label: Text(option.$2),
                                selected: _filter == option.$1,
                                showCheckmark: false,
                                onSelected: (_) => _chooseFilter(option.$1),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (showLocal) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Личные наборы',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text('${decks.length}',
                                style: TextStyle(color: muted)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (decks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Text(
                              _decks.isEmpty
                                  ? 'Создай первый набор, чтобы начать учиться.'
                                  : 'В личных наборах ничего не найдено.',
                              style: TextStyle(color: muted),
                            ),
                          )
                        else
                          for (final deck in decks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _StudyDeckTile(
                                deck: deck,
                                onTap: () => _openDeck(deck),
                              ),
                            ),
                      ],
                      if (showPublic) ...[
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _filter == 'popular'
                                    ? 'Лучшие наборы'
                                    : _filter == 'new'
                                        ? 'Новые публикации'
                                        : 'Общие наборы',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Обновить каталог',
                              onPressed: _loadPublic,
                              icon: const Icon(Icons.refresh_rounded, size: 21),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_publicLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_publicError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_publicError!,
                                    style: TextStyle(color: muted)),
                                TextButton(
                                  onPressed: _loadPublic,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          )
                        else if (_publicDecks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Text(
                              'Публичных наборов пока нет. '
                              'Открой личный набор и опубликуй его.',
                              style: TextStyle(color: muted),
                            ),
                          )
                        else
                          for (final deck in _publicDecks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _PublicStudyDeckTile(
                                deck: deck,
                                onTap: () => _openPublicDeck(deck),
                              ),
                            ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Личные наборы хранятся на устройстве. '
                        'Публичные доступны студентам через сервер CampusApp.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
      ),
    ));
  }
}

class _StudyStat extends StatelessWidget {
  const _StudyStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ServicePalette.accent, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyEmptyState extends StatelessWidget {
  const _StudyEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 29),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            color: ServicePalette.accent,
            size: 46,
          ),
          const SizedBox(height: 14),
          Text(
            'Пока нет наборов',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создай набор по своему предмету, добавь несколько '
            'терминов и начни повторять.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Первый набор'),
          ),
        ],
      ),
    );
  }
}

class _StudyDeckTile extends StatelessWidget {
  const _StudyDeckTile({
    required this.deck,
    required this.onTap,
  });

  final StudyDeck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final progress = deck.cards.isEmpty
        ? 0.0
        : deck.learnedCount / deck.cards.length;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: ServicePalette.accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.style_outlined,
                  color: ServicePalette.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deck.cards.length.toString() + ' карточек · ' +
                          deck.learnedCount.toString() + ' выучено',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        color: ServicePalette.accent,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withOpacity(0.3),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicStudyDeckTile extends StatelessWidget {
  const _PublicStudyDeckTile({
    required this.deck,
    required this.onTap,
  });

  final PublicStudyDeck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: ServicePalette.accent.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: ServicePalette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Автор: ${deck.authorName} · ${deck.cardCount} карточек',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 17, color: ServicePalette.amber),
                        const SizedBox(width: 5),
                        Text(
                          deck.ratingCount == 0
                              ? 'Без оценок'
                              : '${deck.rating.toStringAsFixed(1)} '
                                  '(${deck.ratingCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyDeckScreen extends StatefulWidget {
  const StudyDeckScreen({
    super.key,
    required this.deck,
    required this.onSaved,
    required this.onDelete,
    this.onPublish,
  });

  final StudyDeck deck;
  final Future<void> Function(StudyDeck) onSaved;
  final Future<void> Function(StudyDeck) onDelete;
  final Future<void> Function(StudyDeck)? onPublish;

  @override
  State<StudyDeckScreen> createState() => _StudyDeckScreenState();
}

class _StudyDeckScreenState extends State<StudyDeckScreen> {
  late StudyDeck _deck;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
  }

  Future<void> _save(StudyDeck updated) async {
    await widget.onSaved(updated);
    if (mounted) setState(() => _deck = updated);
  }

  void _errorMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось сохранить изменения')),
    );
  }

  Future<void> _publish() async {
    if (_publishing || widget.onPublish == null) return;
    setState(() => _publishing = true);
    try {
      await widget.onPublish!(_deck);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<StudyDeck>(
      MaterialPageRoute(
        builder: (_) => StudyEditorScreen(deck: _deck),
      ),
    );
    if (updated == null || !mounted) return;
    try {
      await _save(updated);
    } catch (_) {
      _errorMessage();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить набор?'),
        content: Text(
          '«' + _deck.title + '» и весь прогресс будут удалены '
          'с этого телефона.',
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
    try {
      await widget.onDelete(_deck);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _errorMessage();
    }
  }

  void _openCards() {
    if (_deck.cards.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyFlashcardsScreen(
          deck: _deck,
          onChanged: _save,
        ),
      ),
    );
  }

  void _openQuiz() {
    if (_deck.distinctAnswerCount < 2) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyQuizScreen(deck: _deck),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    final total = _deck.cards.length;
    final known = _deck.learnedCount;

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text('Учебный набор'),
        actions: [
          if (widget.onPublish != null)
            IconButton(
              tooltip: 'Опубликовать для студентов',
              onPressed: _publishing ? null : _publish,
              icon: const Icon(Icons.public_rounded),
            ),
          IconButton(
            onPressed: _edit,
            tooltip: 'Редактировать набор',
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Дополнительно',
            onSelected: (value) {
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('Удалить набор'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: theme.colorScheme.surfaceContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    color: ServicePalette.accent,
                    size: 30,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _deck.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_deck.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _deck.description,
                      style: TextStyle(
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    known.toString() + ' из ' + total.toString() + ' выучено',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : known / total,
                      color: ServicePalette.accent,
                      backgroundColor: theme.colorScheme.outlineVariant
                          .withOpacity(0.4),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StudyModeCard(
                    title: 'Карточки',
                    subtitle: 'Переворачивай и повторяй',
                    icon: Icons.style_outlined,
                    color: ServicePalette.accent,
                    onTap: total == 0 ? null : _openCards,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StudyModeCard(
                    title: 'Тест',
                    subtitle: 'Выбери верный ответ',
                    icon: Icons.quiz_outlined,
                    color: ServicePalette.slate,
                    onTap: _deck.distinctAnswerCount < 2
                        ? null
                        : _openQuiz,
                  ),
                ),
              ],
            ),
            if (_deck.distinctAnswerCount < 2) ...[
              const SizedBox(height: 9),
              Text(
                'Для теста нужны хотя бы два разных определения.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Термины набора',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  total.toString(),
                  style: TextStyle(color: muted),
                ),
              ],
            ),
            const SizedBox(height: 13),
            for (final card in _deck.cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: theme.colorScheme.surfaceContainer,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.term,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_deck.knownCardIds.contains(card.id))
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: ServicePalette.accent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.definition,
                        style: TextStyle(
                          color: muted,
                          height: 1.35,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}

class _StudyModeCard extends StatelessWidget {
  const _StudyModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
