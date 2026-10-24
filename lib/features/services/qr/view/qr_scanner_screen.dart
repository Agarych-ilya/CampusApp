import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '/core/theme/app_theme.dart';

/// Scan QR codes locally using the camera. Scan contents are never
/// automatically opened, uploaded, or passed to another service.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  String? _result;
  bool _busy = false;

  bool get _unsupportedDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Uri? get _webAddress {
    final text = _result;
    if (text == null) return null;

    final uri = Uri.tryParse(text.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    return uri;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_result != null || _busy) return;

    String? scanned;
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        scanned = value;
        break;
      }
    }

    if (scanned == null || !mounted) return;
    _busy = true;
    setState(() => _result = scanned);

    try {
      await _scanner.pause();
    } catch (_) {
      // The decoded value is useful even if pausing the camera fails.
    } finally {
      _busy = false;
    }
  }

  Future<void> _scanAgain() async {
    if (_busy) return;
    _busy = true;
    setState(() => _result = null);
    try {
      await _scanner.start();
    } catch (_) {
      if (mounted) _showMessage('Не удалось запустить камеру.');
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scanner.toggleTorch();
    } catch (_) {
      if (mounted) _showMessage('Фонарик недоступен на этом устройстве.');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scanner.switchCamera();
    } catch (_) {
      if (mounted) _showMessage('Не удалось переключить камеру.');
    }
  }

  Future<void> _copyResult() async {
    final value = _result;
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage('Содержимое QR-кода скопировано.');
  }

  Future<void> _openLink() async {
    final uri = _webAddress;
    if (uri == null) return;

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showMessage('Не удалось открыть ссылку.');
    } catch (_) {
      if (mounted) _showMessage('Не удалось открыть ссылку.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR-сканер',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            children: [
              Text(
                'Наведите камеру на QR-код',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Сканирование происходит прямо на устройстве',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _unsupportedDesktop
                      ? _unsupportedPanel(context)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _scanner,
                              fit: BoxFit.cover,
                              tapToFocus: true,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) =>
                                  _cameraErrorPanel(context),
                            ),
                            if (_result == null)
                              const IgnorePointer(
                                child: CustomPaint(
                                  painter: _ScanFramePainter(),
                                ),
                              )
                            else
                              Container(
                                color: Colors.black.withValues(alpha: 0.72),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 58,
                                        color: Color(0xFF4ADEB1),
                                      ),
                                      SizedBox(height: 13),
                                      Text(
                                        'QR-код считан',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_result == null)
                              Positioned(
                                bottom: 20,
                                left: 14,
                                right: 14,
                                child: ValueListenableBuilder<MobileScannerState>(
                                  valueListenable: _scanner,
                                  builder: (context, state, child) {
                                    final torch = state.torchState;
                                    final torchAvailable =
                                        torch != TorchState.unavailable;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _CameraAction(
                                          label: 'Фонарик',
                                          icon: torch == TorchState.on
                                              ? Icons.flash_on
                                              : Icons.flash_off,
                                          active: torch == TorchState.on,
                                          onPressed: torchAvailable
                                              ? _toggleTorch
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        _CameraAction(
                                          label: 'Камера',
                                          icon: Icons.cameraswitch_outlined,
                                          onPressed: _switchCamera,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _result == null
                  ? _readyPanel(context)
                  : _resultPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unsupportedPanel(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'QR-сканер доступен на Android, iOS и в браузере '
            'с разрешённым доступом к камере.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _cameraErrorPanel(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 43),
              const SizedBox(height: 12),
              const Text(
                'Не удалось получить доступ к камере',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверьте разрешение камеры в настройках устройства '
                'и убедитесь, что она не занята другим приложением.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _scanAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readyPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_2_outlined,
            color: AppTheme.pink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Поместите код в рамку. После считывания '
              'здесь появится его содержимое.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel(BuildContext context) {
    final content = _result!;
    final link = _webAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            link == null ? 'Текст QR-кода' : 'Ссылка из QR-кода',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 112),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyResult,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Копировать'),
                ),
              ),
              if (link != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openLink,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Открыть'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy ? null : _scanAgain,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Сканировать ещё'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppTheme.pink
          : Colors.black.withValues(alpha: 0.64),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onPressed == null
                  ? Colors.white54 : Colors.white, size: 20),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null
                      ? Colors.white54 : Colors.white,
                  fontWeight: FontWeight.w700,
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

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide * 0.70;
    final left = (size.width - edge) / 2;
    final top = (size.height - edge) / 2;
    final right = left + edge;
    final bottom = top + edge;
    final corner = edge * 0.17;

    final brush = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void cornerPath(Offset start, Offset middle, Offset end) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(middle.dx, middle.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, brush);
    }

    cornerPath(
      Offset(left, top + corner),
      Offset(left, top),
      Offset(left + corner, top),
    );
    cornerPath(
      Offset(right - corner, top),
      Offset(right, top),
      Offset(right, top + corner),
    );
    cornerPath(
      Offset(right, bottom - corner),
      Offset(right, bottom),
      Offset(right - corner, bottom),
    );
    cornerPath(
      Offset(left + corner, bottom),
      Offset(left, bottom),
      Offset(left, bottom - corner),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => false;
}
