import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../data/saved_nfc_card_storage.dart';

/// Saves a local record of a discovered student card.
/// It does not copy access credentials or emulate the pass at a turnstile.
class NfcPassScreen extends StatefulWidget {
  const NfcPassScreen({super.key});

  @override
  State<NfcPassScreen> createState() => _NfcPassScreenState();
}

class _NfcPassScreenState extends State<NfcPassScreen> {
  final SavedNfcCardStorage _storage = SavedNfcCardStorage();

  NfcAvailability? _availability;
  SavedNfcCard? _savedCard;
  bool _checking = true;
  bool _loadingCard = true;
  bool _scanning = false;
  bool _processing = false;
  bool _justSaved = false;
  String? _error;

  bool get _androidPhone =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _loadSavedCard();
    _checkAvailability();
  }

  Future<void> _loadSavedCard() async {
    try {
      final card = await _storage.read();
      if (mounted) setState(() => _savedCard = card);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось загрузить сохранённую карту.');
      }
    } finally {
      if (mounted) setState(() => _loadingCard = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (!_androidPhone) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (mounted) {
        setState(() {
          _checking = false;
          _availability = availability;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'Не удалось проверить NFC телефона.';
        });
      }
    }
  }

  Future<void> _startReading() async {
    if (!_androidPhone || _scanning || _processing) return;

    if (_availability != NfcAvailability.enabled) {
      await _checkAvailability();
      if (!mounted || _availability != NfcAvailability.enabled) return;
    }

    setState(() {
      _scanning = true;
      _justSaved = false;
      _error = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: _onDiscovered,
      );
    } catch (_) {
      await _stopSession();
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'Не удалось запустить сканирование NFC.';
        });
      }
    }
  }

  Future<void> _onDiscovered(NfcTag tag) async {
    if (!mounted || !_scanning || _processing) return;
    _processing = true;

    try {
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag == null) {
        throw StateError('Устройство не предоставило данные NFC-метки');
      }

      final cardId = androidTag.id
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      final types = androidTag.techList
          .map((name) => name.split('.').last)
          .toList();

      final card = SavedNfcCard(
        identifier: cardId,
        technology: types.isEmpty ? 'NFC ISO 14443' : types.join(', '),
        savedAt: DateTime.now(),
      );

      // Write before displaying success, so the card survives app restart.
      await _storage.save(card);

      if (mounted) {
        setState(() {
          _savedCard = card;
          _justSaved = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _justSaved = false;
          _error = 'Метка обнаружена, но сохранить карту не удалось.';
        });
      }
    } finally {
      _scanning = false;
      await _stopSession();
      _processing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopSession() async {
    if (!_androidPhone) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // The session can already be closed by the OS.
    }
  }

  Future<void> _cancelReading() async {
    if (_processing) return;
    _scanning = false;
    await _stopSession();
    if (mounted) setState(() {});
  }

  Future<void> _deleteCard() async {
    if (_savedCard == null || _scanning || _processing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить запись карты?'),
        content: const Text(
          'Сохранённый идентификатор и сведения о NFC-метке '
          'будут удалены с устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _storage.delete();
      if (mounted) {
        setState(() {
          _savedCard = null;
          _justSaved = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось удалить сохранённую карту.');
      }
    }
  }

  @override
  void dispose() {
    if (_scanning || _processing) _stopSession();
    super.dispose();
  }

  String get _availabilityMessage {
    if (!_androidPhone) {
      return 'Для считывания требуется настоящий Android-телефон с NFC. '
          'Эмулятор и компьютер не могут прочитать физический билет.';
    }
    if (_checking) return 'Проверяем NFC…';
    if (_availability == NfcAvailability.disabled) {
      return 'NFC выключен. Включите его в настройках телефона.';
    }
    if (_availability == NfcAvailability.unsupported) {
      return 'На этом устройстве нет NFC-модуля.';
    }
    return 'NFC включён. Нажмите кнопку и приложите студенческий билет.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const accent = Color(0xFF60A5FA);
    const savedColor = Color(0xFF2DD4BF);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NFC-пропуск',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.nfc, size: 43, color: accent),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Студенческий билет',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Сохрани запись о NFC-карте на своём телефоне',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: (_savedCard == null ? accent : savedColor)
                          .withValues(alpha: 0.13),
                    ),
                    child: Text(
                      _loadingCard
                          ? 'Загружаем запись…'
                          : _savedCard == null
                              ? 'Карта ещё не сохранена'
                              : 'NFC-карта сохранена на устройстве',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _savedCard == null ? accent : savedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            if (_savedCard != null) ...[
              Text(
                'Сохранённая карта',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: savedColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Студенческий билет сохранён',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _CardDetail(
                      title: 'Идентификатор карты',
                      value: _savedCard!.displayIdentifier,
                    ),
                    const SizedBox(height: 8),
                    _CardDetail(
                      title: 'Тип NFC',
                      value: _savedCard!.technology,
                    ),
                    const SizedBox(height: 8),
                    _CardDetail(
                      title: 'Сохранено',
                      value: _savedCard!.formattedDate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Запись хранится локально. Это не копия ключей доступа '
                      'и пока не работает вместо карты на турникете.',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _scanning ? null : _deleteCard,
                        icon: const Icon(Icons.delete_outline, size: 19),
                        label: const Text('Удалить карту'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
            ],
            Text(
              'Сканирование',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _justSaved
                            ? Icons.check_circle_outline
                            : _scanning
                                ? Icons.sensors
                                : Icons.contactless_outlined,
                        color: _justSaved ? savedColor : accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _justSaved
                              ? 'Карта считана и сохранена'
                              : _processing
                                  ? 'Сохраняем карту…'
                                  : _scanning
                                      ? 'Ожидаем NFC-метку…'
                                      : 'Приложи студенческий к телефону',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _justSaved
                        ? 'Карту больше не нужно прикладывать для просмотра '
                          'её сохранённых сведений.'
                        : _scanning
                            ? 'Держи студенческий билет у NFC-антенны '
                              'на задней панели телефона.'
                            : _availabilityMessage,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFE1747F),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 17),
                  if (_scanning)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _processing ? null : _cancelReading,
                        icon: const Icon(Icons.close),
                        label: const Text('Отменить'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _androidPhone &&
                                !_checking &&
                                !_loadingCard &&
                                _availability == NfcAvailability.enabled
                            ? _startReading
                            : null,
                        icon: const Icon(Icons.nfc),
                        label: Text(
                          _savedCard == null
                              ? 'Считать и сохранить карту'
                              : 'Перезаписать карту',
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _checking ? null : _checkAvailability,
                        child: const Text('Проверить NFC снова'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Мобильный пропуск',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF8B8CF8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Для прохода телефоном нужна официальная '
                      'интеграция с университетской СКУД. '
                      'Считывание и сохранение NFC-идентификатора '
                      'не переносит защищённые ключи карты.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
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

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 138,
          child: Text(
            title,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
