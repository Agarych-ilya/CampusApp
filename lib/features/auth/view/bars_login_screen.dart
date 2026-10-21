import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/core/theme/app_theme.dart';

class BarsLoginScreen extends StatelessWidget {
  const BarsLoginScreen({super.key});

  static final Uri _barsUri = Uri.parse(
    'https://bars.mpei.ru/bars_web/Auth/Menu',
  );

  Future<void> _openBars(BuildContext context) async {
    final launched = await launchUrl(
      _barsUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть БАРС МЭИ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppTheme.pink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 44,
                  color: AppTheme.pink,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Campus',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Войди с помощью своей учётной записи МЭИ',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _openBars(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Войти через МЭИ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Авторизация выполняется на стороне МЭИ. '
                'Campus не должен хранить пароль от вашей '
                'учётной записи.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'НИУ «МЭИ»',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
