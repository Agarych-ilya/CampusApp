import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';

// Универсальное сообщение на экране расписания:
// ошибка загрузки или отсутствие занятий.
class ScheduleMessage extends StatelessWidget {
  const ScheduleMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppTheme.pink),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            // Кнопка показывается только если переданы buttonText и onPressed.
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: onPressed,
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    color: AppTheme.pink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
