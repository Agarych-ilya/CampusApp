import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../data/community_api.dart';
import '../widgets/community_avatar.dart';

/// Runs on a background isolate: keeps large photos away from the UI thread.
Uint8List _prepareCommunityIcon(Uint8List bytes) {
  final photo = img.decodeImage(bytes);
  if (photo == null || photo.width < 1 || photo.height < 1) {
    throw const FormatException('Не удалось прочитать изображение.');
  }

  final side = photo.width < photo.height ? photo.width : photo.height;
  final square = img.copyCrop(
    photo,
    x: (photo.width - side) ~/ 2,
    y: (photo.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final preview = img.copyResize(
    square,
    width: 400,
    height: 400,
  );
  return Uint8List.fromList(img.encodeJpg(preview, quality: 82));
}

class AddCommunityScreen extends StatefulWidget {
  const AddCommunityScreen({super.key});

  @override
  State<AddCommunityScreen> createState() => _AddCommunityScreenState();
}

class _AddCommunityScreenState extends State<AddCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = const CommunityApi();
  final _pendingStorage = PendingCommunityStorage();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _telegramController = TextEditingController();
  final _vkController = TextEditingController();

  String _category = communityCategories.first;
  Uint8List? _iconBytes;
  bool _selectingIcon = false;
  bool _submitting = false;

  String get _fallbackIconKind => switch (_category) {
    'Студенческие чаты' => 'chat',
    'Первокурсникам' || 'Учёба' => 'study',
    'Новости и мемы' => 'news',
    'Новости университета' => 'campus',
    'Мероприятия' => 'events',
    _ => 'club',
  };
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _telegramController.dispose();
    _vkController.dispose();
    super.dispose();
  }

  String? _normalizeSocial(String raw, String host) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('@')) text = text.substring(1);

    if (!text.contains('/') && !text.contains(':')) {
      text = 'https://' + host + '/' + text;
    } else if (text.startsWith(host + '/')) {
      text = 'https://' + text;
    }

    return text;
  }

  String? _validateSocial(String? raw, String host) {
    final link = _normalizeSocial(raw ?? '', host);
    if (link == null) return null;

    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.scheme != 'https' ||
        ![host, 'www.' + host].contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.where((part) => part.isNotEmpty).isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_+./-]{1,120}$')
            .hasMatch(uri.path.replaceFirst(RegExp(r'^/'), ''))) {
      return 'Укажи ссылку https://' + host + '/...';
    }

    return null;
  }

  Future<void> _chooseIcon() async {
    if (_submitting || _selectingIcon) return;
    setState(() {
      _selectingIcon = true;
      _error = null;
    });

    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;

      final sourceLength = await file.length();
      if (sourceLength != null && sourceLength > 15 * 1024 * 1024) {
        throw const FormatException('Выбери изображение размером до 15 МБ.');
      }

      final original = await file.readAsBytes();
      if (original.length > 15 * 1024 * 1024) {
        throw const FormatException('Выбери изображение размером до 15 МБ.');
      }

      final icon = await compute(_prepareCommunityIcon, original);
      if (icon.length > 700 * 1024) {
        throw const FormatException(
          'Изображение слишком большое даже после уменьшения.',
        );
      }

      if (mounted) setState(() => _iconBytes = icon);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('FormatException: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _selectingIcon = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    final telegram = _normalizeSocial(_telegramController.text, 't.me');
    final vk = _normalizeSocial(_vkController.text, 'vk.com');

    if (telegram == null && vk == null) {
      setState(() {
        _error = 'Добавь хотя бы одну ссылку: Telegram или ВКонтакте.';
      });
      return;
    }

    final iconBytes = _iconBytes;
    if (iconBytes == null) {
      setState(() => _error = 'Выбери картинку сообщества из галереи.');
      return;
    }

    final draft = CommunityDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      iconKind: _fallbackIconKind,
      telegramUrl: telegram,
      vkUrl: vk,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final id = await _api.submit(
        draft,
        iconBytes: iconBytes,
        extension: 'jpg',
      );
      final localPath = await _pendingStorage.saveIcon(
        id, iconBytes, 'jpg',
      );
      final pending = draft.asPending(id, localIconPath: localPath);

      // The backend has accepted the submission even when local caching fails.
      try {
        await _pendingStorage.save(pending);
      } catch (_) {
        // Reopen this screen from the same device to submit a new group.
      }

      if (!mounted) return;
      Navigator.of(context).pop(pending);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final example = CommunityData(
      id: 'preview',
      title: _titleController.text.trim().isEmpty
          ? 'Моё сообщество'
          : _titleController.text.trim(),
      subtitle: _category,
      description: '',
      category: _category,
      iconKind: _fallbackIconKind,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Добавить сообщество',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CommunityAvatar(
                      community: example,
                      size: 72,
                      previewBytes: _iconBytes,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Твоё сообщество',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Добавь информацию. После проверки '
                            'оно появится у всех студентов.',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(label: 'Основная информация'),
              const SizedBox(height: 13),
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название сообщества',
                  hintText: 'Например, Робототехника МЭИ',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 3) {
                    return 'Название должно содержать минимум 3 символа';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'О чём ваше сообщество и кому оно будет полезно?',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 15) {
                    return 'Добавь описание хотя бы из 15 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in communityCategories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              const SizedBox(height: 23),
              _SectionTitle(label: 'Иконка сообщества'),
              const SizedBox(height: 8),
              Text(
                'Выбери собственную картинку из галереи. Она будет '
                'квадратной и автоматически уменьшится для загрузки.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 13),
              InkWell(
                onTap: _submitting || _selectingIcon ? null : _chooseIcon,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CommunityAvatar(
                        community: example,
                        size: 72,
                        previewBytes: _iconBytes,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _iconBytes == null
                                  ? 'Выбрать изображение'
                                  : 'Изображение выбрано',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _selectingIcon
                                  ? 'Обрабатываем изображение…'
                                  : 'Нажми, чтобы ' +
                                      (_iconBytes == null
                                          ? 'открыть галерею'
                                          : 'заменить иконку'),
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.image_outlined, size: 23),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _SectionTitle(label: 'Количество участников'),
              const SizedBox(height: 8),
              Text(
                'Подписчики и участники определяются автоматически '
                'через Telegram или API ВКонтакте. Если соцсеть '
                'не предоставляет данные, число будет скрыто.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 25),
              _SectionTitle(label: 'Ссылки на соцсети'),
              const SizedBox(height: 8),
              Text(
                'Заполни хотя бы одну ссылку. Допускается @username '
                'или полный адрес страницы.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telegramController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  hintText: 'https://t.me/my_community',
                  prefixIcon: Icon(Icons.send_rounded),
                ),
                validator: (value) => _validateSocial(value, 't.me'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _vkController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'ВКонтакте',
                  hintText: 'https://vk.com/my_community',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                validator: (value) => _validateSocial(value, 'vk.com'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF808D),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    _submitting
                        ? 'Отправляем…'
                        : 'Отправить на проверку',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Заявки публикуются только после проверки модератором. '
                'До этого твоё сообщество будет видно здесь с пометкой '
                '«На проверке».',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
    ),
  );
}

