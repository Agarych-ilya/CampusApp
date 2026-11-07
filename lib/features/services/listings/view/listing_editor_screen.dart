import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/features/profile/data/student_profile_storage.dart';
import '../data/listings_api.dart';

class ListingEditorScreen extends StatefulWidget {
  const ListingEditorScreen({
    super.key,
    required this.kind,
    this.chooseKind = false,
    this.listing,
  });

  final String kind;
  final bool chooseKind;
  final CampusListing? listing;

  @override
  State<ListingEditorScreen> createState() => _ListingEditorScreenState();
}

class _ListingEditorScreenState extends State<ListingEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _location;
  late final TextEditingController _author;
  late final TextEditingController _telegram;

  late String _kind;
  late String _category;
  String _condition = 'good';
  List<Uint8List> _photos = [];
  bool _saving = false;
  String? _error;

  bool get _market => _kind == 'market';
  bool get _editing => widget.listing != null;

  List<String> get _categories =>
      _market
          ? marketCategories.skip(1).where((category) => category != 'Даром').toList()
          : foundCategories.skip(1).toList();

  @override
  void initState() {
    super.initState();
    final item = widget.listing;
    _kind = item?.kind ?? widget.kind;
    _category = item?.category ?? _categories.first;
    if (!_categories.contains(_category)) _category = _categories.first;
    _condition = item?.condition ?? 'good';
    _title = TextEditingController(text: item?.title ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(
      text: item?.price == null ? '' : item!.price.toString(),
    );
    _location = TextEditingController(text: item?.location ?? '');
    _author = TextEditingController(text: item?.authorName ?? '');
    _telegram = TextEditingController(text: item?.telegram ?? '');
    if (!_editing) _fillAuthorFromProfile();
  }

  Future<void> _fillAuthorFromProfile() async {
    try {
      final profile = await StudentProfileStorage().getProfile();
      if (!mounted || _author.text.isNotEmpty) return;
      final name = profile?.fullName.trim() ?? '';
      if (name.isNotEmpty) {
        final parts = name.split(RegExp(r'\s+'));
        setState(() {
          _author.text = parts.length >= 2
              ? parts[0] + ' ' + parts[1][0] + '.'
              : parts.first;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _location, _author, _telegram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePhotos() async {
    if (_editing) return;
    try {
      // file_picker 12.x returns files directly, not FilePickerResult.
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (!mounted || files.isEmpty) return;
      if (files.length > 3) {
        throw Exception('Можно выбрать не больше трёх фотографий');
      }

      final previews = <Uint8List>[];
      for (final file in files) {
        final size = file.lengthSync() ?? await file.length();
        if (size > 5 * 1024 * 1024 || size < 12) {
          throw Exception('Каждое фото должно быть размером до 5 МБ');
        }
        // The native picker can return an Android content URI instead of
        // a file-system path. Read the bytes using the plugin API.
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024 || bytes.length < 12) {
          throw Exception('Каждое фото должно быть размером до 5 МБ');
        }
        previews.add(bytes);
      }
      if (mounted) setState(() => _photos = previews);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _photoTile(Uint8List photo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 95,
        height: 95,
        child: Image.memory(photo, fit: BoxFit.cover),
      ),
    );
  }

  void _changeKind(String next) {
    setState(() {
      _kind = next;
      _category = _categories.first;
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = ListingDraft(
        kind: _kind,
        category: _category,
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: _market ? int.parse(_price.text.trim()) : null,
        condition: _market ? _condition : null,
        location: _location.text.trim(),
        authorName: _author.text.trim(),
        telegram: _telegram.text.trim().replaceFirst('@', ''),
      );
      final CampusListing result;
      if (widget.listing != null) {
        final update = draft.toJson()..remove('kind');
        result = await ListingsApi.instance.update(widget.listing!.id, update);
      } else {
        result = await ListingsApi.instance.create(draft, _photos);
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Редактировать' : 'Новое объявление'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              if (widget.chooseKind && !_editing) ...[
                _section('Что произошло?'),
                Row(
                  children: [
                    for (final option in const [
                      ('lost', 'Потерял'),
                      ('found', 'Нашёл'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                option.$2,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: _kind == option.$1,
                            onSelected: (_) => _changeKind(option.$1),
                            showCheckmark: false,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              _section('Основная информация'),
              TextFormField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _market ? 'Название товара' : 'Что за вещь?',
                  hintText: _market ? 'Например: учебник по ТАУ' : 'Например: ключи с брелоком',
                ),
                validator: (text) => (text ?? '').trim().length < 3
                    ? 'Минимум 3 символа' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: _categories.map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                )).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 6,
                maxLength: 1500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Описание',
                  hintText: _market
                      ? 'Состояние, комплектация, условия передачи...'
                      : 'Приметы, обстоятельства, когда и где...',
                  alignLabelWithHint: true,
                ),
                validator: (text) => (text ?? '').trim().length < 10
                    ? 'Опиши вещь подробнее (от 10 символов)' : null,
              ),
              if (_market) ...[
                const SizedBox(height: 10),
                _section('Цена и состояние'),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Цена в рублях',
                    helperText: 'Введи 0, если отдаёшь даром',
                    prefixIcon: Icon(Icons.currency_ruble_rounded),
                  ),
                  validator: (value) {
                    final price = int.tryParse((value ?? '').trim());
                    return price == null || price < 0 || price > 10000000
                        ? 'Введи цену от 0 до 10 000 000'
                        : null;
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _condition,
                  decoration: const InputDecoration(labelText: 'Состояние'),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('Новое')),
                    DropdownMenuItem(value: 'good', child: Text('Хорошее')),
                    DropdownMenuItem(value: 'used', child: Text('Есть следы использования')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _condition = value);
                  },
                ),
              ],
              const SizedBox(height: 17),
              _section(_market ? 'Место встречи' : 'Где потеряли или нашли?'),
              TextFormField(
                controller: _location,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Место',
                  hintText: _market ? 'Например: у главного входа МЭИ' : 'Например: корпус А, аудитория 204',
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                validator: (value) => !_market &&
                        (value ?? '').trim().isEmpty
                    ? 'Укажи хотя бы примерное место'
                    : null,
              ),
              if (!_editing) ...[
                const SizedBox(height: 14),
                _section('Фотографии'),
                Text(
                  'До 3 фото, каждое до 5 МБ. Можно пропустить.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final file in _photos)
                        Padding(
                          padding: const EdgeInsets.only(right: 9),
                          child: _photoTile(file),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _choosePhotos,
                        child: Container(
                          width: 95,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined),
                              SizedBox(height: 6),
                              Text('Добавить', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Для замены фотографий создай новое объявление.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 26),
              _section('Как с тобой связаться'),
              TextFormField(
                controller: _author,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Отображаемое имя',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Укажи имя для объявления' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telegram,
                maxLength: 33,
                decoration: const InputDecoration(
                  labelText: 'Ник в Telegram',
                  hintText: '@username',
                  prefixIcon: Icon(Icons.send_outlined),
                ),
                validator: (value) {
                  if (!RegExp(r'^@?[a-zA-Z][a-zA-Z0-9_]{4,31}$')
                      .hasMatch((value ?? '').trim())) {
                    return 'Укажи публичный Telegram username';
                  }
                  return null;
                },
              ),
              if (!_market) ...[
                const SizedBox(height: 14),
                Text(
                  'Не публикуй номера студенческих, пропусков, '
                  'паспортов или другие персональные данные. '
                  'Владельцу лучше задать проверочный вопрос.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 15),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Сохраняем...' :
                _editing ? 'Сохранить изменения' : 'Опубликовать'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}
