import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Read-only NFC discovery. This does NOT emulate or clone a campus access
/// card: credential issuance requires an approved integration with the SKUD.
class NfcPassScreen extends StatefulWidget {
  const NfcPassScreen({super.key});

  @override
  State<NfcPassScreen> createState() => _NfcPassScreenState();
}

class _NfcPassScreenState extends State<NfcPassScreen> {
  bool _checking = true;
  bool _scanning = false;
  bool _tagDetected = false;
  NfcAvailability? _availability;
  String? _error;

  bool get _androidPhone =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    if (!_androidPhone) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    if (mounted) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _availability = availability;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Не удалось проверить модуль NFC.';
      });
    }
  }

  Future<void> _startReading() async {
    if (!_androidPhone || _scanning) return;
    if (_availability != NfcAvailability.enabled) {
      await _checkAvailability();
      if (!mounted || _availability != NfcAvailability.enabled) return;
    }

    setState(() {
      _scanning = true;
      _tagDetected = false;
      _error = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          if (!mounted || !_scanning) return;
          setState(() {
            _tagDetected = true;
            _scanning = false;
          });
          await _stopSession();
        },
      );
    } catch (_) {
      await _stopSession();
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Не удалось считать метку. Попробуйте ещё раз.';
      });
    }
  }

  Future<void> _stopSession() async {
    if (!_androidPhone) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // The NFC session may have already ended.
    }
  }

  Future<void> _cancelReading() async {
    await _stopSession();
    if (mounted) setState(() => _scanning = false);
  }

  @override
  void dispose() {
    if (_scanning) {
      // Fire-and-forget cleanup is required by the synchronous dispose API.
      _stopSession();
    }
    super.dispose();
  }

  String get _availabilityMessage {
    if (!_androidPhone) {
      return 'Для проверки NFC нужен реальный Android-телефон с NFC. '
          'Считывание в эмуляторе и на компьютере недоступно.';
    }

    if (_checking) return 'Проверяем доступность NFC…';

    if (_availability == NfcAvailability.disabled) {
      return 'NFC выключен. Включите NFC в настройках телефона '
          'и нажмите «Проверить снова».';
    }

    if (_availability == NfcAvailability.unsupported) {
      return 'Это устройство не поддерживает NFC.';
    }

    return 'NFC доступен. Можно попробовать считать студенческий билет.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const accent = Color(0xFF60A5FA);

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
                  const SizedBox(height: 16),
                  const Text(
                    'Студенческий пропуск',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Проверка считывания NFC-метки вашего билета',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: const Color(0xFFB8860B).withValues(alpha: 0.12),
                    ),
                    child: const Text(
                      'Мобильный пропуск пока не активирован',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2B65E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            Text(
              'Считывание карты',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                        _tagDetected
                            ? Icons.check_circle_outline
                            : _scanning
                                ? Icons.sensors
                                : Icons.contactless_outlined,
                        color: _tagDetected
                            ? const Color(0xFF2DD4BF)
                            : accent,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _tagDetected
                              ? 'NFC-метка обнаружена'
                              : _scanning
                                  ? 'Ожидание NFC-метки…'
                                  : 'Поднесите студенческий билет',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tagDetected
                        ? 'Телефон обнаружил совместимую метку. '
                            'Это не подтверждает подлинность пропуска '
                            'и не создаёт его копию.'
                        : _scanning
                            ? 'Поднесите билет к NFC-антенне телефона '
                                'и удерживайте его рядом.'
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
                  const SizedBox(height: 19),
                  if (_scanning)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelReading,
                        icon: const Icon(Icons.close),
                        label: const Text('Отменить считывание'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _androidPhone &&
                                !_checking &&
                                _availability == NfcAvailability.enabled
                            ? _startReading
                            : null,
                        icon: const Icon(Icons.nfc),
                        label: Text(
                          _tagDetected
                              ? 'Считать ещё раз'
                              : 'Считать NFC-метку',
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
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
            const SizedBox(height: 22),
            Text(
              'Пропуск в телефоне',
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
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: accent,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Требуется интеграция с СКУД МЭИ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Чтобы открывать турникеты телефоном, университет '
                    'должен официально выпускать цифровые пропуска '
                    'и поддерживать их на считывателях. '
                    'Простое считывание NFC-метки не переносит '
                    'защищённые ключи доступа и не заменяет карту.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 17,
                        color: Color(0xFF8B8CF8),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Цифровой пропуск — ожидает подключения',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B8CF8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
