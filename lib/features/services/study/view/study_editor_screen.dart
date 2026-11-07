import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';

import '../data/study_deck.dart';

class StudyEditorScreen extends StatefulWidget {
  const StudyEditorScreen({super.key, this.deck});

  final StudyDeck? deck;

  @override
  State<StudyEditorScreen> createState() => _StudyEditorScreenState();
}

class _CardDraft {
  _CardDraft({
    required this.id,
    String term = '',
    String definition = '',
  })  : term = TextEditingController(text: term),
        definition = TextEditingController(text: definition);

  final String id;
  final TextEditingController term;
  final TextEditingController definition;

  void dispose() {
    term.dispose();
    definition.dispose();
  }
}

class _StudyEditorScreenState extends State<StudyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_CardDraft> _drafts = [];
  final List<_CardDraft> _allDrafts = [];
  late final TextEditingController _title;
  late final TextEditingController _description;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.deck?.title ?? '');
    _description = TextEditingController(
      text: widget.deck?.description ?? '',
    );
    for (final card in widget.deck?.cards ?? <StudyCard>[]) {
      _addDraft(
        id: card.id,
        term: card.term,
        definition: card.definition,
      );
    }
    if (_drafts.isEmpty) {
      _addDraft();
      _addDraft();
    }
  }

  String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toString() +
      '-' + (_serial++).toString();

  void _addDraft({String? id, String term = '', String definition = ''}) {
    final draft = _CardDraft(
      id: id ?? _newId(),
      term: term,
      definition: definition,
    );
    _drafts.add(draft);
    _allDrafts.add(draft);
  }

  void _addCard() {
    if (_drafts.length >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В одном наборе не больше 100 карточек')),
      );
      return;
    }
    setState(() => _addDraft());
  }

  void _removeCard(_CardDraft draft) {
    if (_drafts.length == 1) return;
    setState(() => _drafts.remove(draft));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final deck = widget.deck;
    final cards = _drafts.map((draft) => StudyCard(
      id: draft.id,
      term: draft.term.text.trim(),
      definition: draft.definition.text.trim(),
    )).toList();

    final result = StudyDeck(
      id: deck?.id ?? _newId(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      cards: cards,
      knownCardIds: (deck?.knownCardIds ?? <String>{})
          .where(cards.map((card) => card.id).toSet().contains)
          .toSet(),
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final draft in _allDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Widget _cardField(_CardDraft draft, int index, ThemeData theme) {
    return Container(
      key: ValueKey(draft.id),
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ServicePalette.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (index + 1).toString(),
                  style: const TextStyle(
                    color: ServicePalette.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'КАРТОЧКА',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton(
                onPressed: _drafts.length <= 1
                    ? null
                    : () => _removeCard(draft),
                tooltip: 'Удалить карточку',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.term,
            maxLength: 180,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Например: Передаточная функция',
              labelText: 'Термин / вопрос',
              counterText: '',
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Напиши термин или вопрос'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.definition,
            maxLength: 1200,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Определение или правильный ответ',
              labelText: 'Определение / ответ',
              counterText: '',
              alignLabelWithHint: true,
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Добавь определение или ответ'
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.deck != null;

    return ServicePalette.wrap(context, Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Редактировать набор' : 'Новый набор'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                editing ? 'Настрой свой набор' : 'Создай свой первый набор',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Добавь пары «термин — определение». '
                'Позже их можно изучать и проверять в тесте.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _title,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название набора',
                  hintText: 'Например: ТАУ — определения',
                  prefixIcon: Icon(Icons.auto_stories_outlined),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Укажи название набора'
                    : null,
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _description,
                maxLength: 300,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Описание (необязательно)',
                  hintText: 'Предмет, тема или экзамен',
                ),
              ),
              const SizedBox(height: 21),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Карточки',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _drafts.length.toString() + ' / 100',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              for (var index = 0; index < _drafts.length; index++)
                _cardField(_drafts[index], index, theme),
              const SizedBox(height: 2),
              OutlinedButton.icon(
                onPressed: _addCard,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить карточку'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 14),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(editing ? 'Сохранить набор' : 'Создать набор'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    ));
  }
}
