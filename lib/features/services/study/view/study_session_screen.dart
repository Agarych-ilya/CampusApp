import 'dart:math';

import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../data/study_deck.dart';

class StudyFlashcardsScreen extends StatefulWidget {
  const StudyFlashcardsScreen({
    super.key,
    required this.deck,
    required this.onChanged,
  });

  final StudyDeck deck;
  final Future<void> Function(StudyDeck) onChanged;

  @override
  State<StudyFlashcardsScreen> createState() => _StudyFlashcardsScreenState();
}

class _StudyFlashcardsScreenState extends State<StudyFlashcardsScreen> {
  late List<StudyCard> _cards;
  late Set<String> _knownIds;
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  bool _shuffled = false;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.deck.cards);
    _knownIds = Set.of(widget.deck.knownCardIds);
  }

  void _restart() {
    setState(() {
      _index = 0;
      _revealed = false;
      _cards = List.of(widget.deck.cards);
      if (_shuffled) _cards.shuffle(Random());
    });
  }

  void _shuffle() {
    setState(() => _shuffled = !_shuffled);
    _restart();
  }

  Future<void> _mark({required bool known}) async {
    if (_saving || _index >= _cards.length) return;
    final updated = Set<String>.of(_knownIds);
    final id = _cards[_index].id;
    if (known) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    setState(() => _saving = true);
    try {
      await widget.onChanged(widget.deck.copyWith(knownCardIds: updated));
      if (!mounted) return;
      setState(() {
        _knownIds = updated;
        _index++;
        _revealed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить прогресс')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final finished = _index >= _cards.length;
    final learned = _cards
        .where((card) => _knownIds.contains(card.id))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточки'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _shuffle,
            tooltip: _shuffled ? 'Исходный порядок' : 'Перемешать',
            icon: Icon(
              Icons.shuffle_rounded,
              color: _shuffled ? AppTheme.pink : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: finished
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.pink.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.pink,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Круг завершён!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ты знаешь ' + learned.toString() + ' из ' +
                          _cards.length.toString() + ' карточек.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 25),
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Пройти ещё раз'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.deck.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          (_index + 1).toString() + ' / ' +
                              _cards.length.toString(),
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: _index / _cards.length,
                        minHeight: 5,
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        color: AppTheme.pink,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _revealed = !_revealed),
                        borderRadius: BorderRadius.circular(26),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          child: Container(
                            key: ValueKey(_cards[_index].id +
                                (_revealed ? '-back' : '-front')),
                            width: double.infinity,
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: _revealed
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _revealed
                                    ? AppTheme.pink.withOpacity(0.4)
                                    : theme.colorScheme.outlineVariant
                                        .withOpacity(0.55),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _revealed
                                          ? Icons.lightbulb_outline_rounded
                                          : Icons.style_outlined,
                                      color: AppTheme.pink,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _revealed ? 'ОПРЕДЕЛЕНИЕ' : 'ТЕРМИН',
                                      style: const TextStyle(
                                        color: AppTheme.pink,
                                        fontSize: 11,
                                        letterSpacing: 1.3,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Center(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _revealed
                                            ? _cards[_index].definition
                                            : _cards[_index].term,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Нажми, чтобы ' +
                                      (_revealed
                                          ? 'увидеть термин'
                                          : 'открыть ответ'),
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_revealed)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => setState(() => _revealed = true),
                          icon: const Icon(Icons.flip_rounded),
                          label: const Text('Показать ответ'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _mark(known: false),
                              icon: const Icon(Icons.refresh_rounded, size: 19),
                              label: const Text('Повторить'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _mark(known: true),
                              icon: const Icon(Icons.check_rounded, size: 19),
                              label: const Text('Знаю'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
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
}

class StudyQuizScreen extends StatefulWidget {
  const StudyQuizScreen({super.key, required this.deck});

  final StudyDeck deck;

  @override
  State<StudyQuizScreen> createState() => _StudyQuizScreenState();
}

class _StudyQuizScreenState extends State<StudyQuizScreen> {
  late List<StudyCard> _questions;
  late List<String> _options;
  int _index = 0;
  int _correct = 0;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  void _startQuiz() {
    _questions = List.of(widget.deck.cards)..shuffle(Random());
    _index = 0;
    _correct = 0;
    _selected = null;
    _options = _optionsFor(_questions.first);
  }

  List<String> _optionsFor(StudyCard card) {
    final seen = <String>{card.definition.trim().toLowerCase()};
    final distractors = <String>[];
    final others = List.of(widget.deck.cards)..shuffle(Random());
    for (final other in others) {
      final key = other.definition.trim().toLowerCase();
      if (seen.add(key)) distractors.add(other.definition);
      if (distractors.length == 3) break;
    }
    return [card.definition, ...distractors]..shuffle(Random());
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      if (_index < _questions.length) {
        _options = _optionsFor(_questions[_index]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final finished = _index >= _questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Тест')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: finished
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: AppTheme.pink,
                      size: 78,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Тест завершён',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _correct.toString() + ' из ' +
                          _questions.length.toString() + ' верно',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.pink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => setState(_startQuiz),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Пройти ещё раз'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ВЫБЕРИ ПРАВИЛЬНОЕ ОПРЕДЕЛЕНИЕ',
                            style: TextStyle(
                              color: AppTheme.pink,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        Text(
                          (_index + 1).toString() + '/' +
                              _questions.length.toString(),
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: _index / _questions.length,
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        color: AppTheme.pink,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Text(
                        _questions[_index].term,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < _options.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: OutlinedButton(
                                onPressed: _selected == null
                                    ? () => setState(() {
                                        _selected = _options[i];
                                        if (_selected ==
                                            _questions[_index].definition) {
                                          _correct++;
                                        }
                                      })
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  disabledForegroundColor:
                                      theme.colorScheme.onSurface,
                                  backgroundColor: _selected != null &&
                                          _options[i] ==
                                              _questions[_index].definition
                                      ? Colors.green.withOpacity(0.14)
                                      : _selected == _options[i]
                                          ? Colors.red.withOpacity(0.12)
                                          : theme.colorScheme.surfaceContainer,
                                  side: BorderSide(
                                    color: _selected != null &&
                                            _options[i] ==
                                                _questions[_index].definition
                                        ? Colors.green
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        String.fromCharCode(65 + i),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(_options[i]),
                                    ),
                                    if (_selected != null &&
                                        _options[i] ==
                                            _questions[_index].definition)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_selected != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(_index == _questions.length - 1
                              ? 'Результаты'
                              : 'Следующий вопрос'),
                        ),
                      )
                    else
                      Text(
                        'Выбери один вариант ответа',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
