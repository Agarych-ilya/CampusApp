import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';
import '../data/public_study_api.dart';
import '../data/study_deck.dart';
import 'study_session_screen.dart';

class StudyPublicDeckScreen extends StatefulWidget {
  const StudyPublicDeckScreen({
    super.key,
    required this.preview,
    required this.onSaveCopy,
    required this.onChanged,
  });

  final PublicStudyDeck preview;
  final Future<void> Function(StudyDeck) onSaveCopy;
  final Future<void> Function() onChanged;

  @override
  State<StudyPublicDeckScreen> createState() => _StudyPublicDeckScreenState();
}

class _StudyPublicDeckScreenState extends State<StudyPublicDeckScreen> {
  PublicStudyDeck? _deck;
  StudyDeck? _study;
  String? _error;
  bool _busy = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deck = await PublicStudyApi.instance.get(widget.preview.id);
      if (!mounted) return;
      setState(() {
        _deck = deck;
        _study = deck.asStudyDeck();
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _errorMessage(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _rate(int stars) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await PublicStudyApi.instance.rate(widget.preview.id, stars);
      if (!mounted) return;
      setState(() => _deck = updated);
      await widget.onChanged();
    } catch (e) {
      _errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _ratingDialog() {
    if (_busy) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Оцени учебный набор',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Можно изменить оценку позже'),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var stars = 1; stars <= 5; stars++)
                    IconButton(
                      tooltip: '$stars из 5',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _rate(stars);
                      },
                      icon: Icon(
                        stars <= (_deck?.myRating ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: ServicePalette.amber,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCopy() async {
    if (_study == null || _busy || _copied) return;
    setState(() => _busy = true);
    try {
      await widget.onSaveCopy(_deck!.asPersonalCopy());
      if (!mounted) return;
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Копия сохранена в «Мои наборы»')),
      );
    } catch (e) {
      _errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить публикацию?'),
        content: const Text(
          'Общий набор и его оценки будут удалены. '
          'Личная версия на телефоне останется.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await PublicStudyApi.instance.delete(widget.preview.id);
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _practice() async {
    if (_study == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StudyFlashcardsScreen(
          deck: _study!,
          onChanged: (deck) async {
            if (mounted) setState(() => _study = deck);
          },
        ),
      ),
    );
  }

  void _quiz() {
    if (_study == null || _study!.distinctAnswerCount < 2) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StudyQuizScreen(deck: _study!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ServicePalette.theme(Theme.of(context));
    final muted = theme.colorScheme.onSurfaceVariant;
    final deck = _deck ?? widget.preview;

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: const Text('Общий набор'),
        actions: [
          if (deck.isMine)
            IconButton(
              tooltip: 'Удалить публикацию',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Повторить')),
                ],
              ))
            : _study == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(21),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(deck.title,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900)),
                            if (deck.description.isNotEmpty) ...[
                              const SizedBox(height: 9),
                              Text(deck.description,
                                  style: TextStyle(color: muted, height: 1.4)),
                            ],
                            const SizedBox(height: 15),
                            Text('Автор: ${deck.authorName}',
                                style: TextStyle(color: muted, fontSize: 13)),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: ServicePalette.amber, size: 21),
                                const SizedBox(width: 5),
                                Text(deck.ratingCount == 0
                                    ? 'Нет оценок'
                                    : '${deck.rating.toStringAsFixed(1)} '
                                      '(${deck.ratingCount})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Text('${deck.cardCount} карточек',
                                    style: TextStyle(color: muted)),
                              ],
                            ),
                            if (!deck.isMine) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _ratingDialog,
                                icon: const Icon(Icons.star_border_rounded,
                                    color: ServicePalette.amber),
                                label: Text(deck.myRating == null
                                    ? 'Оценить набор'
                                    : 'Моя оценка: ${deck.myRating} ★'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _practice,
                              icon: const Icon(Icons.style_outlined),
                              label: const Text('Карточки'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _study!.distinctAnswerCount < 2
                                  ? null : _quiz,
                              icon: const Icon(Icons.quiz_outlined),
                              label: const Text('Тест'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _copied || _busy ? null : _saveCopy,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(_copied
                            ? 'Сохранено в мои наборы'
                            : 'Сохранить копию себе'),
                      ),
                      const SizedBox(height: 24),
                      Text('Термины',
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      for (final card in _study!.cards)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.term,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 7),
                              Text(card.definition,
                                  style: TextStyle(color: muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    ));
  }
}
